/* global axios */
import ApiClient from './ApiClient';

class PipedriveAPI extends ApiClient {
  constructor() {
    super('integrations/pipedrive', { accountScoped: true });
  }

  getFilters(type) {
    return axios.get(`${this.url}/filters`, { params: { type } });
  }

  getDeals(params) {
    return axios.get(`${this.url}/deals`, { params });
  }

  getLeads(params) {
    return axios.get(`${this.url}/leads`, { params });
  }

  getActivities(params) {
    return axios.get(`${this.url}/activities`, { params });
  }

  createDeal(payload) {
    return axios.post(`${this.url}/create_deal`, payload);
  }

  createLead(payload) {
    return axios.post(`${this.url}/create_lead`, { lead: payload });
  }

  createActivity(payload) {
    return axios.post(`${this.url}/create_activity`, { activity: payload });
  }

  getUsers(term = '') {
    const url = `${this.url}/users`;
    return axios.get(url, { params: { term } });
  }

  getPersons(term = '') {
    const url = `${this.url}/persons`;
    return axios.get(url, { params: { term } });
  }

  getOrganizations(term = '') {
    const url = `${this.url}/organizations`;
    return axios.get(url, { params: { term } });
  }

  getLeadLabels() {
    const url = `${this.url}/lead_labels`;
    return axios.get(url);
  }

  getProducts(term = '') {
    const url = `${this.url}/search_products`;
    return axios.get(url, { params: { term } });
  }
}

export default new PipedriveAPI();
