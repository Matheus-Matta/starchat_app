import ApiClient from '../ApiClient';

class CosmosBulkActionsAPI extends ApiClient {
  constructor() {
    super('cosmos/bulk_actions', { accountScoped: true });
  }
}

export default new CosmosBulkActionsAPI();
