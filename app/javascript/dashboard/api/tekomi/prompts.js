import ApiClient from '../ApiClient';

class TekomiPrompts extends ApiClient {
  constructor() {
    super('tekomi/prompts', { accountScoped: true });
  }

  save(key, body) {
    return this.update(key, { body });
  }

  restore(key) {
    return this.delete(key);
  }
}

export default new TekomiPrompts();
