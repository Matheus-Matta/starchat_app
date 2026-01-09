import CosmosDocumentAPI from 'dashboard/api/cosmos/document';
import { createStore } from './storeFactory';

export default createStore({
  name: 'CosmosDocument',
  API: CosmosDocumentAPI,
});
