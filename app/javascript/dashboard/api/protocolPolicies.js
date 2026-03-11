import ApiClient from './ApiClient';

class ProtocolPoliciesAPI extends ApiClient {
  constructor() {
    super('protocol_policies', { accountScoped: true });
  }
}

export default new ProtocolPoliciesAPI();
