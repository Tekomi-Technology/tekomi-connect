/* global axios */
import ApiClient from './ApiClient';

class PhoneExtensionsAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  getAll(inboxId) {
    return axios.get(`${this.url}/${inboxId}/phone_extensions`);
  }

  create(inboxId, phoneExtension) {
    return axios.post(`${this.url}/${inboxId}/phone_extensions`, {
      phone_extension: phoneExtension,
    });
  }

  update(inboxId, extensionId, phoneExtension) {
    return axios.patch(
      `${this.url}/${inboxId}/phone_extensions/${extensionId}`,
      { phone_extension: phoneExtension }
    );
  }

  delete(inboxId, extensionId) {
    return axios.delete(
      `${this.url}/${inboxId}/phone_extensions/${extensionId}`
    );
  }
}

export default new PhoneExtensionsAPI();
