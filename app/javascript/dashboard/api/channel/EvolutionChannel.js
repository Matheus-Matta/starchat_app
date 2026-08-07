// app/javascript/api/channel/EvolutionChannel.js
/* global axios */
import ApiClient from '../ApiClient';

class EvolutionChannel extends ApiClient {
  constructor() {
    // base: /api/v1/accounts/:account_id/channels/evolution_channel
    super('channels/evolution_channel', { accountScoped: true });
  }

  create(payload) {
    return super.create(payload);
  }

  show(id) {
    return super.show(id);
  }

  connect(id) {
    return axios.post(`${this.url}/${id}/connect`);
  }

  restart(id) {
    return axios.post(`${this.url}/${id}/restart`);
  }

  disconnect(id) {
    return axios.post(`${this.url}/${id}/disconnect`);
  }

  getSettings(id) {
    return axios.get(`${this.url}/${id}/settings`);
  }

  updateSettings(id, settings) {
    return axios.patch(`${this.url}/${id}/settings`, { settings });
  }

  migrateToWhatsapp(id, whatsappChannel) {
    return axios.post(`${this.url}/${id}/migrate_to_whatsapp`, {
      whatsapp_channel: whatsappChannel,
    });
  }
}

export default new EvolutionChannel();
