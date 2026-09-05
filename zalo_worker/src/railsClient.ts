import type { ZaloCredentials } from './types.js';

export interface SessionRecord {
  channel_id: number;
  credentials: ZaloCredentials;
}

/**
 * Talks to Rails, which owns every piece of durable state. The worker never reads the database.
 * Both directions authenticate with the same shared secret; the worker binds to loopback only.
 */
export class RailsClient {
  constructor(
    private baseUrl: string,
    private secret: string
  ) {}

  /** Channels with stored credentials, fetched once on boot so the worker can restore sessions. */
  async fetchSessions(): Promise<SessionRecord[]> {
    const res = await fetch(`${this.baseUrl}/internal/zalo_personal/sessions`, {
      headers: { 'X-Zalo-Worker-Secret': this.secret },
    });
    if (!res.ok) throw new Error(`fetchSessions failed: ${res.status}`);
    const body = (await res.json()) as { sessions: SessionRecord[] };
    return body.sessions ?? [];
  }

  /**
   * Deliver one event to Rails, which enqueues it for processing. Rails responds as soon as the
   * job is queued, so this stays fast enough to call from a websocket callback.
   */
  async postEvent(payload: Record<string, unknown>): Promise<void> {
    const res = await fetch(`${this.baseUrl}/webhooks/zalo_personal`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Zalo-Worker-Secret': this.secret },
      body: JSON.stringify(payload),
    });
    if (!res.ok) throw new Error(`postEvent(${payload.event}) failed: ${res.status}`);
  }
}
