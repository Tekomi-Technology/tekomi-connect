import { RailsRequestError } from './railsClient.js';

export const RETRY_BASE_MS = 1_000;
export const RETRY_MAX_DELAY_MS = 30_000;
// Long enough to ride out a Rails restart or deploy; past this the event is given up on.
export const RETRY_WINDOW_MS = 15 * 60 * 1000;
// Bounds memory while Rails is down. Each entry is one Zalo event, so this is hours of traffic.
export const MAX_PENDING_EVENTS = 5_000;

type Payload = Record<string, unknown>;

interface ForwarderLog {
  info: (obj: Record<string, unknown>, msg: string) => void;
  warn: (obj: Record<string, unknown>, msg: string) => void;
  error: (obj: Record<string, unknown>, msg: string) => void;
}

export interface ForwarderDeps {
  post: (payload: Payload) => Promise<void>;
  log: ForwarderLog;
  sleep?: (ms: number) => Promise<void>;
  now?: () => number;
}

// Network failures, timeouts and 5xx mean Rails was briefly unreachable; any other 4xx means the
// event itself is rejected and resending it would fail the same way.
export function isRetryable(err: unknown): boolean {
  if (err instanceof RailsRequestError) return err.status >= 500 || err.status === 408 || err.status === 429;
  return true;
}

export function retryDelay(attempt: number): number {
  return Math.min(RETRY_BASE_MS * 2 ** attempt, RETRY_MAX_DELAY_MS);
}

/**
 * Delivers Zalo events to Rails without losing them when Rails is briefly down. Zalo never
 * resends an event, so a failed post is retried with backoff instead of dropped. Events for the
 * same channel go out one at a time, in arrival order, so a retry cannot let a later message
 * overtake an earlier one. Rails dedupes on msg_id, so a post that timed out after Rails had
 * already queued it is harmless to repeat.
 */
export class EventForwarder {
  private chains = new Map<string, Promise<void>>();
  private pending = 0;
  private sleep: (ms: number) => Promise<void>;
  private now: () => number;

  constructor(private deps: ForwarderDeps) {
    this.sleep = deps.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
    this.now = deps.now ?? Date.now;
  }

  get pendingCount(): number {
    return this.pending;
  }

  forward(key: string, payload: Payload): Promise<void> {
    if (this.pending >= MAX_PENDING_EVENTS) {
      this.deps.log.error({ event: payload.event, key, pending: this.pending }, 'forward queue full, event dropped');
      return Promise.resolve();
    }

    this.pending += 1;
    const previous = this.chains.get(key) ?? Promise.resolve();
    const next = previous
      .then(() => this.deliver(payload))
      .finally(() => {
        this.pending -= 1;
        if (this.chains.get(key) === next) this.chains.delete(key);
      });
    this.chains.set(key, next);
    return next;
  }

  private async deliver(payload: Payload): Promise<void> {
    const startedAt = this.now();
    for (let attempt = 0; ; attempt += 1) {
      try {
        await this.deps.post(payload);
        if (attempt > 0) this.deps.log.info({ event: payload.event, attempts: attempt + 1 }, 'forward recovered');
        return;
      } catch (err) {
        const gaveUp = !isRetryable(err) || this.now() - startedAt >= RETRY_WINDOW_MS;
        if (gaveUp) {
          this.deps.log.error({ err: String(err), event: payload.event, attempts: attempt + 1 }, 'forward failed, event dropped');
          return;
        }
        const delay = retryDelay(attempt);
        this.deps.log.warn({ err: String(err), event: payload.event, attempt: attempt + 1, retry_in_ms: delay }, 'forward failed, retrying');
        await this.sleep(delay);
      }
    }
  }
}
