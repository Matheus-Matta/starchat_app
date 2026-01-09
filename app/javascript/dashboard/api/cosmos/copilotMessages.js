/* global axios */
import ApiClient from '../ApiClient';

class CosmosMessages extends ApiClient {
  constructor() {
    super('cosmos/copilot_threads', { accountScoped: true });
  }

  get(threadId) {
    return axios.get(`${this.url}/${threadId}/copilot_messages`);
  }

  create({ threadId, ...rest }) {
    return axios.post(`${this.url}/${threadId}/copilot_messages`, rest);
  }
}

export default new CosmosMessages();
