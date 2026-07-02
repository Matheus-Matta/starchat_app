/* global axios */
import ApiClient from './ApiClient';

class WhatsappTemplateReportsAPI extends ApiClient {
  constructor() {
    super('reports', { accountScoped: true, apiVersion: 'v2' });
  }

  get({ inboxId, since, until } = {}) {
    return axios.get(`${this.url}/whatsapp_templates`, {
      params: { inbox_id: inboxId, since, until },
    });
  }
}

export default new WhatsappTemplateReportsAPI();
