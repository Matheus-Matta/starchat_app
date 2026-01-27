/* global axios */
import ApiClient from '../ApiClient';

class CosmosPreferences extends ApiClient {
  constructor() {
    super('cosmos/preferences', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  updatePreferences(data) {
    return axios.put(this.url, data);
  }
}

export default new CosmosPreferences();
