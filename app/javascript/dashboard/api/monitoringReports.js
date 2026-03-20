/* global axios */
import ApiClient from './ApiClient';

class MonitoringReportsAPI extends ApiClient {
  constructor() {
    super('monitoring', { accountScoped: true, apiVersion: 'v2' });
  }

  getSnapshot() {
    return axios.get(this.url);
  }
}

export default new MonitoringReportsAPI();
