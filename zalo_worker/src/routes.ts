import type { FastifyInstance } from 'fastify';
import { SessionManager, NoSessionError } from './sessionManager.js';
import { ReconnectSupervisor } from './supervisor.js';
import { startQrLogin, type QrLoginResult, type QrFailureReason } from './qrLogin.js';
import { once } from './idempotency.js';
import { ZaloThreadKind, ZaloFileRejectedError, type QuoteSource, type ZaloCredentials } from './types.js';

export interface RouteDeps {
  sessions: SessionManager;
  supervisor: ReconnectSupervisor;
  credentials: Map<number, ZaloCredentials>;
  reportQrLogin: (result: QrLoginResult) => Promise<void>;
  reportQrFailure: (qrSessionId: string, reason: QrFailureReason) => Promise<void>;
  secret: string;
  log: (obj: Record<string, unknown>, msg: string) => void;
}

interface SendBody {
  thread_id: string;
  kind: 'user' | 'group';
  content?: string;
  quote_source?: QuoteSource;
  idempotency_key?: string;
}

function threadKind(kind: string): ZaloThreadKind {
  return kind === 'group' ? ZaloThreadKind.Group : ZaloThreadKind.User;
}

export function registerRoutes(app: FastifyInstance, deps: RouteDeps): void {
  // Loopback-only binding plus a shared secret: Rails is the only caller.
  app.addHook('onRequest', async (request, reply) => {
    if (request.headers['x-zalo-worker-secret'] !== deps.secret) {
      await reply.code(401).send({ error: 'unauthorized' });
    }
  });

  app.get('/health', async () => ({
    sessions: deps.sessions.ids().map((channelId) => ({ channel_id: channelId, connected: true })),
  }));

  app.post('/qr/start', async () => {
    const { qrSessionId, qrImage } = await startQrLogin(deps.reportQrLogin, deps.reportQrFailure, deps.log);
    return { qr_session_id: qrSessionId, qr_image: qrImage };
  });

  app.post<{ Params: { channelId: string }; Body: { credentials: ZaloCredentials } }>(
    '/sessions/:channelId/connect',
    async (request, reply) => {
      const channelId = Number(request.params.channelId);
      deps.credentials.set(channelId, request.body.credentials);
      // Connecting can take seconds and may retry with backoff; the supervisor reports the
      // outcome to Rails through the status event, so the caller does not wait for it.
      void deps.supervisor.connect(channelId);
      return reply.code(202).send({ status: 'connecting' });
    }
  );

  // Rails asks for a display name when it first sees a thread, so a group becomes a contact
  // named after the group rather than after whoever happened to speak first.
  app.get<{ Params: { channelId: string }; Querystring: { kind: string; id: string } }>(
    '/sessions/:channelId/profile',
    async (request, reply) => {
      const channelId = Number(request.params.channelId);
      const { kind, id } = request.query;
      try {
        const profile =
          kind === 'group'
            ? await deps.sessions.getGroupInfo(channelId, id)
            : await deps.sessions.getUserInfo(channelId, id);
        return {
          name: 'name' in profile ? profile.name : profile.displayName,
          avatar_url: profile.avatar ?? null,
        };
      } catch (error) {
        if (error instanceof NoSessionError) return reply.code(409).send({ error: 'no_session' });
        deps.log({ channelId, kind, id, err: String(error) }, 'profile lookup failed');
        return reply.code(502).send({ error: 'profile_lookup_failed' });
      }
    }
  );

  app.delete<{ Params: { channelId: string } }>('/sessions/:channelId', async (request, reply) => {
    const channelId = Number(request.params.channelId);
    await deps.supervisor.remove(channelId);
    deps.credentials.delete(channelId);
    return reply.code(204).send();
  });

  app.post<{ Params: { channelId: string } }>('/sessions/:channelId/send', async (request, reply) => {
    const channelId = Number(request.params.channelId);
    try {
      const result = request.isMultipart()
        ? await sendAttachment(deps, channelId, request)
        : await sendText(deps, channelId, request.body as SendBody);
      return { msg_id: result.msgId };
    } catch (error) {
      return respondToSendError(reply, error, deps, channelId);
    }
  });
}

async function sendText(deps: RouteDeps, channelId: number, body: SendBody) {
  return once(body.idempotency_key, () =>
    deps.sessions.sendText(channelId, body.thread_id, threadKind(body.kind), body.content ?? '', body.quote_source)
  );
}

// Rails streams the attachment as multipart rather than base64 so a large file does not
// inflate by a third on the way through.
async function sendAttachment(deps: RouteDeps, channelId: number, request: any) {
  const file = await request.file();
  if (!file) throw new Error('multipart send without a file part');

  const fields = file.fields ?? {};
  const value = (name: string): string => String(fields[name]?.value ?? '');
  const data = await file.toBuffer();

  return once(value('idempotency_key') || undefined, () =>
    deps.sessions.sendAttachment(
      channelId,
      value('thread_id'),
      threadKind(value('kind')),
      { filename: file.filename, data },
      value('caption')
    )
  );
}

function respondToSendError(reply: any, error: unknown, deps: RouteDeps, channelId: number) {
  if (error instanceof NoSessionError) {
    return reply.code(409).send({ error: 'no_session', message: error.message });
  }
  if (error instanceof ZaloFileRejectedError) {
    return reply.code(422).send({ error: 'file_rejected', message: error.message });
  }
  deps.log({ channelId, err: String(error) }, 'send failed');
  return reply.code(500).send({ error: 'send_failed', message: String(error) });
}
