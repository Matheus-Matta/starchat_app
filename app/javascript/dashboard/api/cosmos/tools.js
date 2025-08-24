/* global axios */
import ApiClient from '../ApiClient';

class CosmosTools extends ApiClient {
  constructor() {
    super('cosmos/assistants/tools', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, {
      params,
    });
  }
}

export default new CosmosTools();
