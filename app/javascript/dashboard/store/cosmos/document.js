import CaptainDocumentAPI from 'dashboard/api/cosmos/document';
import { createStore } from './storeFactory';

export default createStore({
  name: 'CaptainDocument',
  API: CaptainDocumentAPI,
});
