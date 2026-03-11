/* global axios */
import ApiClient from './ApiClient';

class ProtocolsAPI extends ApiClient {
  constructor() {
    super('protocols', { accountScoped: true });
  }

  /**
   * Lista protocolos com filtros opcionais.
   * @param {Object} params - { contact_id, protocol_policy_id, status, q, page }
   */
  get(params = {}) {
    return axios.get(this.url, { params });
  }

  /**
   * Fecha um protocolo (status → closed).
   */
  close(id) {
    return axios.post(`${this.url}/${id}/close`);
  }

  /**
   * Reabre um protocolo (status → open).
   */
  reopen(id) {
    return axios.post(`${this.url}/${id}/reopen`);
  }
}

export default new ProtocolsAPI();
