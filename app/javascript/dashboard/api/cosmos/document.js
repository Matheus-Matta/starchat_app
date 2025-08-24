/* global axios */
import ApiClient from '../ApiClient';

class CosmosDocument extends ApiClient {
  constructor() {
    super('cosmos/documents', { accountScoped: true });
  }

  get({ page = 1, searchKey, assistantId } = {}) {
    return axios.get(this.url, {
      params: {
        page,
        searchKey,
        assistant_id: assistantId,
      },
    });
  }
}

export default new CosmosDocument();
