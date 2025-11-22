/* global axios */
import ApiClient from '../ApiClient';

class CosmosResponses extends ApiClient {
  constructor() {
    super('cosmos/assistant_responses', { accountScoped: true });
  }

  get({ page = 1, search, assistantId, documentId, status } = {}) {
    return axios.get(this.url, {
      params: {
        page,
        search,
        assistant_id: assistantId,
        document_id: documentId,
        status,
      },
    });
  }
}

export default new CosmosResponses();
