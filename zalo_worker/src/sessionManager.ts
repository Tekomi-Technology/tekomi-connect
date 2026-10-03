import { ZaloApi, ZaloThreadKind, IncomingMessage, ReactionEvent, UndoEvent, QuoteSource } from './types.js';

/** Live zca-js sessions, keyed by Chatwoot channel id. In memory only — Rails owns the credentials. */
export class SessionManager {
  private sessions = new Map<number, ZaloApi>();
  private onMessage?: (channelId: number, msg: IncomingMessage) => void;
  private onReaction?: (channelId: number, evt: ReactionEvent) => void;
  private onUndo?: (channelId: number, evt: UndoEvent) => void;

  /** Register the app-level handlers bound to every session on bindInbound. */
  registerEventHandlers(handlers: {
    onMessage: (channelId: number, msg: IncomingMessage) => void;
    onReaction: (channelId: number, evt: ReactionEvent) => void;
    onUndo: (channelId: number, evt: UndoEvent) => void;
  }): void {
    this.onMessage = handlers.onMessage;
    this.onReaction = handlers.onReaction;
    this.onUndo = handlers.onUndo;
  }

  register(channelId: number, api: ZaloApi): void {
    this.sessions.set(channelId, api);
  }

  bindInbound(channelId: number): void {
    const api = this.require(channelId);
    if (this.onMessage) api.onMessage((msg) => this.onMessage!(channelId, msg));
    if (this.onReaction) api.onReaction((evt) => this.onReaction!(channelId, evt));
    if (this.onUndo) api.onUndo((evt) => this.onUndo!(channelId, evt));
  }

  has(channelId: number): boolean {
    return this.sessions.has(channelId);
  }

  ids(): number[] {
    return [...this.sessions.keys()];
  }

  private require(channelId: number): ZaloApi {
    const api = this.sessions.get(channelId);
    if (!api) throw new NoSessionError(channelId);
    return api;
  }

  async sendText(channelId: number, threadId: string, kind: ZaloThreadKind, text: string, quote?: QuoteSource) {
    return this.require(channelId).sendText(threadId, kind, text, quote);
  }

  async sendAttachment(
    channelId: number,
    threadId: string,
    kind: ZaloThreadKind,
    file: { filename: string; data: Buffer },
    caption: string
  ) {
    return this.require(channelId).sendAttachment(threadId, kind, file, caption);
  }

  async getUserInfo(channelId: number, uid: string) {
    return this.require(channelId).getUserInfo(uid);
  }

  async getGroupInfo(channelId: number, groupId: string) {
    return this.require(channelId).getGroupInfo(groupId);
  }

  /** Stop and forget one channel's session (inbox deleted, or reconnecting). */
  async remove(channelId: number): Promise<void> {
    const api = this.sessions.get(channelId);
    if (!api) return;
    try {
      await api.stop();
    } catch {
      /* already closed */
    }
    this.sessions.delete(channelId);
  }

  async stopAll(): Promise<void> {
    await Promise.all([...this.sessions.values()].map((s) => s.stop().catch(() => {})));
    this.sessions.clear();
  }
}

/** No live session for this channel — Rails turns this into a 409 so the message fails visibly. */
export class NoSessionError extends Error {
  constructor(public readonly channelId: number) {
    super(`No active Zalo session for channel ${channelId}`);
  }
}
