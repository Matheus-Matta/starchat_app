/* global axios */
import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  confirm(campaignId) {
    return axios.post(`${this.url}/${campaignId}/confirm`);
  }

  previewContacts(audience, page = 1) {
    // POST (not GET) because axios's default query-string serializer encodes
    // nested arrays as audience[0][contact_ids][0]=... which Rails parses back
    // as a Hash keyed "0" instead of an Array, crashing the controller.
    return axios.post(`${this.url}/preview_contacts`, { audience, page });
  }

  getContacts(campaignId, page = 1) {
    return axios.get(`${this.url}/${campaignId}/contacts`, {
      params: { page },
    });
  }

  matchContacts(payload = {}) {
    // Forwards the full payload: ids / identifiers / phones / emails,
    // plus optional create_missing and phone_names for phone imports.
    return axios.post(`${this.url}/match_contacts`, payload);
  }
}

export default new CampaignsAPI();
