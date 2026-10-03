/* global axios */
import ApiClient from '../ApiClient';

class ZaloPersonalChannel extends ApiClient {
  constructor() {
    super('zalo_personal', { accountScoped: true });
  }

  // Starts a QR login. Pass channelId to re-authenticate an inbox whose session expired.
  startAuthorization(channelId) {
    return axios.post(
      `${this.baseUrl()}/zalo_personal/authorizations`,
      channelId ? { channel_id: channelId } : {}
    );
  }

  // Polled while the QR code is on screen, until the scan completes or the code expires.
  getAuthorization(qrSessionId) {
    return axios.get(
      `${this.baseUrl()}/zalo_personal/authorizations/${qrSessionId}`
    );
  }
}

export default new ZaloPersonalChannel();
