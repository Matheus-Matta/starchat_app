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

  createDeal(deal) {
    return axios.post(`${this.url}/create_deal`, { deal });
  }

  updateDeal(id, deal) {
    return axios.patch(`${this.url}/update_deal`, { id, deal });
  }

  deleteDeal(id) {
    return axios.delete(`${this.url}/delete_deal`, { params: { id } });
  }

  getLeads(contactId) {
    return axios.get(`${this.url}/leads`, {
      params: { contact_id: contactId },
    });
  }

  createLead(lead) {
    return axios.post(`${this.url}/create_lead`, { lead });
  }

  updateLead(id, lead) {
    return axios.patch(`${this.url}/update_lead`, { id, lead });
  }

  deleteLead(id) {
    return axios.delete(`${this.url}/delete_lead`, { params: { id } });
  }

  getActivities(contactId) {
    return axios.get(`${this.url}/activities`, {
      params: { contact_id: contactId },
    });
  }

  createActivity(activity) {
    return axios.post(`${this.url}/create_activity`, { activity });
  }

  updateActivity(id, activity) {
    return axios.patch(`${this.url}/update_activity`, { id, activity });
  }

  deleteActivity(id) {
    return axios.delete(`${this.url}/delete_activity`, { params: { id } });
  }
}

export default new PipedriveAPI();
