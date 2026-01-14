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
}

export default new PipedriveAPI();
