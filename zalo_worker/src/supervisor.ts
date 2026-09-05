import type { ZaloCredentials } from './types.js';

export type SessionStatus = 'connected' | 'reconnecting' | 'expired';

/**
 * Conservative auth-error classifier for a zca-js login rejection.
 * Returns true ONLY when the message clearly indicates a credential/session problem.
 * Everything else (network, unknown) is treated as retryable — a wrong `expired`
 * forces a manual QR re-scan, while a wrong retry only costs a backoff delay.
 */
export function isZaloAuthError(err: unknown): boolean {
  const msg = String((err as { message?: unknown })?.message ?? '').toLowerCase();
  if (!msg) return false;
  return /cookie|credential|unauthor|đăng nhập|(login|session|token).*(fail|expired|invalid|reject)|(invalid|expired|reject).*(login|session|token)/.test(
    msg
  );
}

/** The slice of an adapter the supervisor drives. ZcaAdapter satisfies it structurally. */
export interface SupervisedAdapter {
  onClosed(cb: (code: number, reason: string) => void): void;
  getSerializedCookie(): unknown;
  stop(): Promise<void>;
}

/** All I/O the supervisor needs, injected so it stays testable. */
export interface ReconnectDeps {
  loadCredentials(channelId: number): Promise<ZaloCredentials | null>;
  saveCredentials(channelId: number, creds: ZaloCredentials): Promise<void>;
  createAdapter(channelId: number, creds: ZaloCredentials): Promise<SupervisedAdapter>;
  register(channelId: number, adapter: SupervisedAdapter): void;
  unregister(channelId: number): Promise<void>;
  bindInbound(channelId: number): void;
  setStatus(channelId: number, status: SessionStatus): Promise<void>;
  log(obj: Record<string, unknown>, msg: string): void;
}

// Exponential backoff (ms); the last value is the cap.
export const BACKOFF_MS = [5_000, 15_000, 45_000, 120_000, 300_000];
const MANUAL_CLOSE = 1000;

interface ChannelState {
  attempt: number;
  connecting: boolean;
  stopped: boolean;
  epoch: number;
  adapter?: SupervisedAdapter;
  timer?: NodeJS.Timeout;
}

export class ReconnectSupervisor {
  private state = new Map<number, ChannelState>();

  constructor(private deps: ReconnectDeps) {}

  /** Re-persist the live cookie for every currently-connected channel. Never throws. */
  async persistAllCookies(): Promise<void> {
    for (const [channelId, st] of this.state) {
      if (!st.adapter) continue;
      try {
        const creds = await this.deps.loadCredentials(channelId);
        if (creds) await this.persistCookie(channelId, st.adapter, creds);
      } catch (err) {
        this.deps.log({ channelId, err: String(err) }, 'failed to persist refreshed cookie');
      }
    }
  }

  /** Stop supervising a channel (inbox deleted). Cancels any pending reconnect. */
  async remove(channelId: number): Promise<void> {
    const st = this.ensure(channelId);
    st.stopped = true;
    st.epoch++; // supersede any in-flight connect() for this removed channel
    if (st.timer) clearTimeout(st.timer);
    st.timer = undefined;
    st.adapter = undefined;
    await this.deps.unregister(channelId).catch(() => {});
  }

  /** Connect (or reconnect) one channel. Never throws. */
  async connect(channelId: number): Promise<void> {
    const st = this.ensure(channelId);
    if (st.connecting) return; // guard against overlapping attempts
    st.connecting = true;
    st.stopped = false;
    const epoch = ++st.epoch; // this attempt's generation; onClosed/remove bump st.epoch to supersede it
    const isCurrent = () => st.epoch === epoch && !st.stopped;
    try {
      const creds = await this.deps.loadCredentials(channelId);
      if (!creds || !isCurrent()) return;
      const adapter = await this.deps.createAdapter(channelId, creds); // may throw
      if (!isCurrent()) {
        await adapter.stop().catch(() => {});
        return;
      }
      this.deps.register(channelId, adapter);
      this.deps.bindInbound(channelId);
      adapter.onClosed((code, reason) => this.onClosed(channelId, code, reason));
      st.adapter = adapter;
      st.attempt = 0;
      await this.transition(channelId, 'connected');
      if (!isCurrent()) return; // a close interleaved during setStatus; onClosed already handled it
      await this.persistCookie(channelId, adapter, creds);
    } catch (err) {
      st.adapter = undefined;
      if (isZaloAuthError(err)) {
        this.deps.log({ channelId, err: String(err) }, 'zalo re-login auth failure; marking expired');
        await this.transition(channelId, 'expired');
        return;
      }
      this.deps.log({ channelId, err: String(err) }, 'zalo connect failed; will retry');
      await this.transition(channelId, 'reconnecting');
      this.scheduleReconnect(channelId);
    } finally {
      st.connecting = false;
    }
  }

  /** Single choke point for status changes. */
  private async transition(channelId: number, status: SessionStatus): Promise<void> {
    this.deps.log({ channelId, status }, 'channel status changed');
    await this.deps.setStatus(channelId, status).catch(() => {});
  }

  private async persistCookie(channelId: number, adapter: SupervisedAdapter, creds: ZaloCredentials): Promise<void> {
    try {
      const cookie = adapter.getSerializedCookie();
      if (cookie == null) return;
      await this.deps.saveCredentials(channelId, { ...creds, cookie });
    } catch (err) {
      this.deps.log({ channelId, err: String(err) }, 'failed to persist refreshed cookie');
    }
  }

  private ensure(channelId: number): ChannelState {
    let s = this.state.get(channelId);
    if (!s) {
      s = { attempt: 0, connecting: false, stopped: false, epoch: 0 };
      this.state.set(channelId, s);
    }
    return s;
  }

  private onClosed(channelId: number, code: number, reason: string): void {
    const st = this.ensure(channelId);
    st.adapter = undefined;
    st.epoch++; // supersede any in-flight connect() so it won't overwrite status back to connected
    if (st.stopped) return;
    if (code === MANUAL_CLOSE) return; // we closed it on purpose
    this.deps.log({ channelId, code, reason }, 'zalo session closed; scheduling reconnect');
    void this.deps.unregister(channelId).catch(() => {});
    void this.transition(channelId, 'reconnecting');
    this.scheduleReconnect(channelId);
  }

  private scheduleReconnect(channelId: number): void {
    const st = this.ensure(channelId);
    if (st.timer) clearTimeout(st.timer);
    const ms = BACKOFF_MS[Math.min(st.attempt, BACKOFF_MS.length - 1)];
    st.attempt++;
    st.timer = setTimeout(() => {
      st.timer = undefined;
      if (st.stopped) return;
      void this.connect(channelId);
    }, ms);
  }
}
