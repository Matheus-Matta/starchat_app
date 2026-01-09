/* global axios */
import ApiClient from '../ApiClient';

class CosmosScenarios extends ApiClient {
  constructor() {
    super('cosmos/assistants', { accountScoped: true });
  }

  get({ assistantId, page = 1, searchKey } = {}) {
    return axios.get(`${this.url}/${assistantId}/scenarios`, {
      params: { page, searchKey },
    });
  }

  show({ assistantId, id }) {
    return axios.get(`${this.url}/${assistantId}/scenarios/${id}`);
  }

  create({ assistantId, ...data } = {}) {
    return axios.post(`${this.url}/${assistantId}/scenarios`, {
      scenario: data,
    });
  }

  update({ assistantId, id }, data = {}) {
    return axios.put(`${this.url}/${assistantId}/scenarios/${id}`, {
      scenario: data,
    });
  }

  delete({ assistantId, id }) {
    return axios.delete(`${this.url}/${assistantId}/scenarios/${id}`);
  }
}

export default new CosmosScenarios();
