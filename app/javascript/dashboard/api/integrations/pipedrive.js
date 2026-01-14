/* global axios */

import ApiClient from '../ApiClient';

class PipedriveAPI extends ApiClient {
  constructor() {
    super('integrations/pipedrive', { accountScoped: true });
  }

  getCustomerContext(contactId) {
    return axios.get(`${this.url}/customer_context`, {
      params: { contact_id: contactId },
    });
  }

  getDeals(contactId) {
    return axios.get(`${this.url}/deals`, {
      params: { contact_id: contactId },
    });
  }

  getLeads(contactId) {
    return axios.get(`${this.url}/leads`, {
      params: { contact_id: contactId },
    });
  }

  getActivities(contactId) {
    return axios.get(`${this.url}/activities`, {
      params: { contact_id: contactId },
    });
  }
}

export default new PipedriveAPI();
