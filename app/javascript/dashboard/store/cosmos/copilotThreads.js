import CopilotThreadsAPI from 'dashboard/api/cosmos/copilotThreads';
import { createStore } from './storeFactory';

export default createStore({
  name: 'CopilotThreads',
  API: CopilotThreadsAPI,
});
