/* global axios */
import ApiClient from '../ApiClient';

class CosmosDocument extends ApiClient {
  constructor() {
    super('cosmos/documents', { accountScoped: true });
  }

  get({ page = 1, searchKey, assistantId, filter, source, sort } = {}) {
    return axios.get(this.url, {
      params: {
        page,
        search_key: searchKey,
        assistant_id: assistantId,
        filter,
        source,
        sort,
      },
    });
  }

  sync(id) {
    return axios.post(`${this.url}/${id}/sync`);
  }
}

export default new CosmosDocument();
