import ApiClient from '../ApiClient';

class CosmosThreads extends ApiClient {
  constructor() {
    super('cosmos/copilot_threads', { accountScoped: true });
  }
}

export default new CosmosThreads();
