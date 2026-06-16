/* global axios */

import ApiClient from './ApiClient';

class ConversationFlowsAPI extends ApiClient {
  constructor() {
    super('conversation_flows', { accountScoped: true });
  }

  getInboxes(flowId) {
    return axios.get(`${this.url}/${flowId}/inboxes`);
  }

  addInbox(flowId, inboxId) {
    return axios.post(`${this.url}/${flowId}/inboxes`, { inbox_id: inboxId });
  }

  removeInbox(flowId, inboxId) {
    return axios.delete(`${this.url}/${flowId}/inboxes/${inboxId}`);
  }
}

export default new ConversationFlowsAPI();
