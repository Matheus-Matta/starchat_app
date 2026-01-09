import CosmosAssistantAPI from 'dashboard/api/cosmos/assistant';
import { createStore } from './storeFactory';

export default createStore({
  name: 'CosmosAssistant',
  API: CosmosAssistantAPI,
});
