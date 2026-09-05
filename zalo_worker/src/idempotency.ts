/**
 * Guards against sending the same message to Zalo twice.
 *
 * Rails retries a send through Sidekiq whenever the HTTP call fails — including the case where
 * Zalo accepted the message but the response never reached Rails. Without this, that retry
 * delivers a duplicate to the customer. Rails passes a stable key per (message, attachment index);
 * a repeat of a key we already completed returns the original msgId instead of sending again.
 *
 * In memory and short-lived on purpose: it closes the timeout/crash-after-send window, which is
 * seconds wide. A worker restart loses the map, and that is acceptable — the alternative is
 * persisting state the worker is explicitly not meant to own.
 */
const TTL_MS = 5 * 60 * 1000;

interface Entry {
  msgId: string;
  expiresAt: number;
}

const done = new Map<string, Entry>();
const inFlight = new Map<string, Promise<{ msgId: string }>>();

function sweep(): void {
  const now = Date.now();
  for (const [key, entry] of done) {
    if (entry.expiresAt <= now) done.delete(key);
  }
}

/**
 * Run `send` at most once per key. A concurrent call with the same key awaits the first one
 * rather than starting a second send.
 */
export async function once(key: string | undefined, send: () => Promise<{ msgId: string }>): Promise<{ msgId: string }> {
  if (!key) return send();

  const completed = done.get(key);
  if (completed && completed.expiresAt > Date.now()) return { msgId: completed.msgId };

  const running = inFlight.get(key);
  if (running) return running;

  const promise = send()
    .then((result) => {
      done.set(key, { msgId: result.msgId, expiresAt: Date.now() + TTL_MS });
      return result;
    })
    .finally(() => {
      inFlight.delete(key);
      sweep();
    });

  inFlight.set(key, promise);
  return promise;
}
