import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  confirm(campaignId) {
    return axios.post(`${this.url}/${campaignId}/confirm`);
  }

  previewContacts(audience, page = 1) {
    return axios.get(`${this.url}/preview_contacts`, {
      params: { audience, page },
    });
  }

  getContacts(campaignId, page = 1) {
    return axios.get(`${this.url}/${campaignId}/contacts`, {
      params: { page },
    });
  }

  matchContacts({ phones = [], emails = [] }) {
    return axios.post(`${this.url}/match_contacts`, { phones, emails });
  }
}

export default new CampaignsAPI();
