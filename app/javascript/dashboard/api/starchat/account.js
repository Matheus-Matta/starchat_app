/* global axios */
import ApiClient from '../ApiClient';

class StarchatAccountAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
    this.apiVersion = '/starchat/api/v1';
  }

  checkout() {
    return axios.post(`${this.url}checkout`);
  }

  subscription() {
    return axios.post(`${this.url}subscription`);
  }

  getLimits() {
    return axios.get(`${this.url}limits`).catch(error => {
      // Suppress 404 errors for installations that don't have this route
      if (error.response?.status === 404) {
        return { data: {} };
      }
      throw error;
    });
  }

  toggleDeletion(action) {
    return axios.post(`${this.url}toggle_deletion`, {
      action_type: action,
    });
  }

  createTopupCheckout(credits) {
    return axios.post(`${this.url}topup_checkout`, { credits });
  }
}

export default new StarchatAccountAPI();
