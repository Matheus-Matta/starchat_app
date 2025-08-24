import CaptainAssistantAPI from 'dashboard/api/cosmos/assistant';
import { createStore } from './storeFactory';

export default createStore({
  name: 'CaptainAssistant',
  API: CaptainAssistantAPI,
});
