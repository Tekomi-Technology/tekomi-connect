import Fastify from 'fastify';
import multipart from '@fastify/multipart';
import { SessionManager } from './sessionManager.js';
import { ReconnectSupervisor, type SessionStatus } from './supervisor.js';
import { ZcaAdapter } from './zcaAdapter.js';
import { RailsClient } from './railsClient.js';
import { registerRoutes } from './routes.js';
import { isReactionRemoval, reactionEmoji } from './reactionIcons.js';
import type { QrLoginResult } from './qrLogin.js';
import type { IncomingMessage, ReactionEvent, UndoEvent, ZaloCredentials } from './types.js';

const PORT = Number(process.env.ZALO_WORKER_PORT ?? 3100);
// Loopback by default so a single-host install cannot expose the worker. Compose deployments
// set 0.0.0.0 because Rails runs in a separate container; the port is not published to the
// host there, so the worker stays reachable only from the compose network, behind the secret.
const HOST = process.env.ZALO_WORKER_HOST ?? '127.0.0.1';
const SECRET = process.env.ZALO_WORKER_SECRET ?? '';
const RAILS_BASE_URL = process.env.RAILS_BASE_URL ?? 'http://127.0.0.1:3000';
const COOKIE_PERSIST_MS = 30 * 60 * 1000;

// A missing secret would leave the send/connect endpoints open to anything that can reach the
// port, so refuse to start rather than run unauthenticated.
if (!SECRET) throw new Error('ZALO_WORKER_SECRET is required');

const app = Fastify({ logger: true });
const rails = new RailsClient(RAILS_BASE_URL, SECRET);
const sessions = new SessionManager();

// Credentials live here only while the process runs; Rails is the system of record.
const credentials = new Map<number, ZaloCredentials>();

const log = (obj: Record<string, unknown>, msg: string) => app.log.info(obj, msg);

const supervisor = new ReconnectSupervisor({
  loadCredentials: async (channelId) => credentials.get(channelId) ?? null,
  saveCredentials: async (channelId, creds) => {
    credentials.set(channelId, creds);
    await rails.postEvent({ event: 'credentials_refreshed', channel_id: channelId, credentials: creds });
  },
  createAdapter: (_channelId, creds) => ZcaAdapter.fromCredentials(creds),
  register: (channelId, adapter) => sessions.register(channelId, adapter as never),
  unregister: (channelId) => sessions.remove(channelId),
  bindInbound: (channelId) => sessions.bindInbound(channelId),
  setStatus: (channelId, status: SessionStatus) =>
    rails.postEvent({ event: 'status', channel_id: channelId, status }),
  log,
});

// Every inbound event is forwarded as-is; Rails owns all the decisions about what to store.
// A failed post is logged and dropped: Zalo will not resend, and there is nowhere durable to
// queue it here without giving the worker the state it is meant not to own.
const forward = (payload: Record<string, unknown>) => {
  rails.postEvent(payload).catch((err) => app.log.error({ err: String(err), event: payload.event }, 'forward failed'));
};

sessions.registerEventHandlers({
  onMessage: (channelId, msg: IncomingMessage) => forward(messagePayload(channelId, msg)),
  onReaction: (channelId, evt: ReactionEvent) => {
    if (isReactionRemoval(evt.icon)) return; // un-reacting is not surfaced
    forward({
      event: 'reaction',
      channel_id: channelId,
      kind: evt.kind,
      thread_id: evt.threadId,
      reacted_msg_id: evt.reactedMsgId,
      emoji: reactionEmoji(evt.icon),
      sender_name: evt.senderName || evt.senderUid,
      is_self: evt.isSelf,
    });
  },
  onUndo: (channelId, evt: UndoEvent) => {
    if (!evt.isSelf) return; // a customer recall stays visible to the agent on purpose
    forward({
      event: 'undo',
      channel_id: channelId,
      kind: evt.kind,
      thread_id: evt.threadId,
      recalled_msg_id: evt.recalledMsgId,
    });
  },
});

function messagePayload(channelId: number, msg: IncomingMessage): Record<string, unknown> {
  const c = msg.classified;
  return {
    event: 'message',
    channel_id: channelId,
    kind: msg.kind,
    thread_id: msg.threadId,
    msg_id: msg.msgId,
    sender_uid: msg.senderUid,
    sender_name: msg.senderName,
    is_self: msg.isSelf,
    quote_msg_id: msg.quoteMsgId ?? null,
    quote_source: msg.quoteSrc,
    content: msg.text,
    media: c.kind === 'media' ? { type: c.mediaType, url: c.href, filename: c.filename } : null,
  };
}

const reportQrLogin = async (result: QrLoginResult) => {
  await rails.postEvent({
    event: 'qr_completed',
    qr_session_id: result.qrSessionId,
    zalo_uid: result.zaloUid,
    display_name: result.displayName,
    credentials: result.credentials,
  });
};

const reportQrFailure = async (qrSessionId: string, reason: string) => {
  await rails.postEvent({ event: 'qr_failed', qr_session_id: qrSessionId, reason });
};

await app.register(multipart, { limits: { fileSize: 100 * 1024 * 1024 } });
registerRoutes(app, { sessions, supervisor, credentials, reportQrLogin, reportQrFailure, secret: SECRET, log });

// Rails does not know when the worker restarts, so the worker asks for the channels to restore.
// Both start together under compose, so Rails is routinely not listening yet on the first try;
// keep asking rather than leaving every session down until someone restarts the worker.
const RESTORE_RETRY_MS = 10_000;

async function restoreSessions(): Promise<void> {
  let records;
  try {
    records = await rails.fetchSessions();
  } catch (err) {
    app.log.warn({ err: String(err) }, 'rails not reachable yet; retrying session restore');
    setTimeout(() => void restoreSessions(), RESTORE_RETRY_MS).unref();
    return;
  }

  for (const record of records) {
    credentials.set(record.channel_id, record.credentials);
    void supervisor.connect(record.channel_id);
  }
  app.log.info({ count: records.length }, 'restored zalo sessions');
}

// Re-persist live cookies so a restart logs in with a fresh cookie, not the one from the QR scan.
const cookieTimer = setInterval(() => void supervisor.persistAllCookies(), COOKIE_PERSIST_MS);
cookieTimer.unref();

const shutdown = async () => {
  clearInterval(cookieTimer);
  await supervisor.persistAllCookies().catch(() => {});
  await sessions.stopAll();
  await app.close();
  process.exit(0);
};

process.on('SIGTERM', () => void shutdown());
process.on('SIGINT', () => void shutdown());

await app.listen({ port: PORT, host: HOST });
void restoreSessions();
