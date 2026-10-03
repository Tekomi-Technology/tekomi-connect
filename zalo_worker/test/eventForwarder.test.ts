import { describe, it, expect, vi } from 'vitest';
import { EventForwarder, isRetryable, retryDelay, RETRY_WINDOW_MS, RETRY_MAX_DELAY_MS } from '../src/eventForwarder.js';
import { RailsRequestError } from '../src/railsClient.js';

function setup(post: (payload: Record<string, unknown>) => Promise<void>) {
  let clock = 0;
  const log = { info: vi.fn(), warn: vi.fn(), error: vi.fn() };
  const forwarder = new EventForwarder({
    post,
    log,
    sleep: async (ms) => {
      clock += ms;
    },
    now: () => clock,
  });
  return { forwarder, log };
}

describe('isRetryable', () => {
  it('retries network failures, 5xx, 408 and 429', () => {
    expect(isRetryable(new TypeError('fetch failed'))).toBe(true);
    expect(isRetryable(new RailsRequestError(502, 'bad gateway'))).toBe(true);
    expect(isRetryable(new RailsRequestError(408, 'timeout'))).toBe(true);
    expect(isRetryable(new RailsRequestError(429, 'busy'))).toBe(true);
  });

  it('does not retry an event Rails rejected', () => {
    expect(isRetryable(new RailsRequestError(401, 'bad secret'))).toBe(false);
    expect(isRetryable(new RailsRequestError(422, 'invalid'))).toBe(false);
  });
});

describe('retryDelay', () => {
  it('doubles and caps the delay', () => {
    expect(retryDelay(0)).toBe(1_000);
    expect(retryDelay(3)).toBe(8_000);
    expect(retryDelay(20)).toBe(RETRY_MAX_DELAY_MS);
  });
});

describe('EventForwarder', () => {
  it('retries until Rails accepts the event', async () => {
    const post = vi
      .fn()
      .mockRejectedValueOnce(new TypeError('fetch failed'))
      .mockRejectedValueOnce(new RailsRequestError(503, 'restarting'))
      .mockResolvedValueOnce(undefined);
    const { forwarder, log } = setup(post);

    await forwarder.forward('1', { event: 'message', msg_id: 'a' });

    expect(post).toHaveBeenCalledTimes(3);
    expect(log.info).toHaveBeenCalledWith(expect.objectContaining({ attempts: 3 }), 'forward recovered');
    expect(log.error).not.toHaveBeenCalled();
  });

  it('drops an event Rails rejects without retrying', async () => {
    const post = vi.fn().mockRejectedValue(new RailsRequestError(401, 'bad secret'));
    const { forwarder, log } = setup(post);

    await forwarder.forward('1', { event: 'message' });

    expect(post).toHaveBeenCalledTimes(1);
    expect(log.error).toHaveBeenCalledWith(expect.anything(), 'forward failed, event dropped');
  });

  it('gives up once the retry window has passed', async () => {
    const post = vi.fn().mockRejectedValue(new TypeError('fetch failed'));
    const { forwarder, log } = setup(post);

    await forwarder.forward('1', { event: 'message' });

    const totalWait = post.mock.calls.slice(0, -1).reduce((sum, _call, i) => sum + retryDelay(i), 0);
    expect(totalWait).toBeGreaterThanOrEqual(RETRY_WINDOW_MS);
    expect(log.error).toHaveBeenCalledWith(expect.anything(), 'forward failed, event dropped');
  });

  it('keeps events for one channel in arrival order while retrying', async () => {
    const delivered: string[] = [];
    let failFirst = true;
    const post = vi.fn(async (payload: Record<string, unknown>) => {
      if (payload.msg_id === 'first' && failFirst) {
        failFirst = false;
        throw new TypeError('fetch failed');
      }
      delivered.push(String(payload.msg_id));
    });
    const { forwarder } = setup(post);

    await Promise.all([
      forwarder.forward('1', { event: 'message', msg_id: 'first' }),
      forwarder.forward('1', { event: 'message', msg_id: 'second' }),
    ]);

    expect(delivered).toEqual(['first', 'second']);
    expect(forwarder.pendingCount).toBe(0);
  });
});
