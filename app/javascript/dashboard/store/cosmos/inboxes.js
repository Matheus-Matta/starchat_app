import CosmosInboxes from 'dashboard/api/cosmos/inboxes';
import { createStore } from './storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export default createStore({
  name: 'CosmosInbox',
  API: CosmosInboxes,
  actions: mutations => ({
    delete: async function remove({ commit }, { inboxId, assistantId }) {
      commit(mutations.SET_UI_FLAG, { deletingItem: true });
      try {
        await CosmosInboxes.delete({ inboxId, assistantId });
        commit(mutations.DELETE, inboxId);
        commit(mutations.SET_UI_FLAG, { deletingItem: false });
        return inboxId;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { deletingItem: false });
        return throwErrorMessage(error);
      }
    },
  }),
});
