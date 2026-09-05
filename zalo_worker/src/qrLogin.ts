import { Zalo, LoginQRCallbackEventType } from 'zca-js';
import type { LoginQRCallbackEvent } from 'zca-js';
import { randomUUID } from 'node:crypto';
import type { ZaloCredentials } from './types.js';

export interface QrLoginResult {
  qrSessionId: string;
  zaloUid: string;
  displayName: string;
  credentials: ZaloCredentials;
}

export interface QrStarted {
  qrSessionId: string;
  qrImage: string; // data: URL, rendered directly by the dashboard
}

type Report = (result: QrLoginResult) => Promise<void>;
export type QrFailureReason = 'expired' | 'declined';
type ReportFailure = (qrSessionId: string, reason: QrFailureReason) => Promise<void>;
type Log = (obj: Record<string, unknown>, msg: string) => void;

function toDataUrl(image: string | undefined): string {
  if (!image) return '';
  return image.startsWith('data:') ? image : `data:image/png;base64,${image}`;
}

/**
 * Start a QR login and resolve as soon as the code is renderable. The scan itself completes
 * later: when Zalo hands over the credentials, `report` delivers them to Rails, which creates
 * (or re-authenticates) the channel and then asks the worker to open the real session.
 *
 * The login here is deliberately thrown away after reading the account id — the session that
 * actually serves the inbox is created from the stored credentials, so there is exactly one
 * code path that opens a live session.
 */
export function startQrLogin(report: Report, reportFailure: ReportFailure, log: Log): Promise<QrStarted> {
  const qrSessionId = randomUUID();
  const zalo = new Zalo({ selfListen: true });

  return new Promise<QrStarted>((resolve, reject) => {
    let settled = false;
    let displayName = '';
    let credentials: ZaloCredentials | null = null;

    const login = zalo.loginQR({}, async (event: LoginQRCallbackEvent) => {
      if (event.type === LoginQRCallbackEventType.QRCodeGenerated && !settled) {
        settled = true;
        resolve({ qrSessionId, qrImage: toDataUrl((event.data as any)?.image) });
      }
      if (event.type === LoginQRCallbackEventType.QRCodeScanned) {
        displayName = String((event.data as any)?.display_name ?? '');
      }
      // Zalo gave up on this code. Say so now: otherwise the dashboard keeps polling a dead
      // code until the pending record expires, minutes after the code itself did.
      if (event.type === LoginQRCallbackEventType.QRCodeExpired) {
        await reportFailure(qrSessionId, 'expired').catch(() => {});
      }
      if (event.type === LoginQRCallbackEventType.QRCodeDeclined) {
        await reportFailure(qrSessionId, 'declined').catch(() => {});
      }
      if (event.type === LoginQRCallbackEventType.GotLoginInfo) {
        const data = event.data as any;
        credentials = { imei: data.imei, cookie: data.cookie, userAgent: data.userAgent, language: 'vi' };
      }
    });

    login
      .then(async (api: any) => {
        if (!credentials) throw new Error('QR login finished without credentials');
        const zaloUid = String(api?.getOwnId?.() ?? '');
        if (!zaloUid) throw new Error('QR login finished without an account id');
        try {
          api?.listener?.stop?.();
        } catch {
          /* the listener may not have been started */
        }
        await report({ qrSessionId, zaloUid, displayName, credentials });
      })
      .catch((err: unknown) => {
        log({ qrSessionId, err: String(err) }, 'qr login failed');
        if (!settled) {
          settled = true;
          reject(err);
        }
      });
  });
}
