import CosmosBulkActionsAPI from 'dashboard/api/cosmos/bulkActions';
import { createStore } from './storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export default createStore({
  name: 'CosmosBulkAction',
  API: CosmosBulkActionsAPI,
  actions: mutations => ({
    processBulkAction: async function processBulkAction(
      { commit },
      { type, actionType, ids }
    ) {
      commit(mutations.SET_UI_FLAG, { isUpdating: true });
      try {
        const response = await CosmosBulkActionsAPI.create({
          type: type,
          ids,
          fields: { status: actionType },
        });
        commit(mutations.SET_UI_FLAG, { isUpdating: false });
        return response.data;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { isUpdating: false });
        return throwErrorMessage(error);
      }
    },

    handleBulkDelete: async function handleBulkDelete(
      { dispatch },
      { type = 'AssistantResponse', ids }
    ) {
      const response = await dispatch('processBulkAction', {
        type,
        actionType: 'delete',
        ids,
      });

      // Update the response store after successful API call
      await dispatch('cosmosResponses/removeBulkResponses', ids, {
        root: true,
      });
      return response;
    },

    handleBulkApprove: async function handleBulkApprove({ dispatch }, ids) {
      const response = await dispatch('processBulkAction', {
        type: 'AssistantResponse',
        actionType: 'approve',
        ids,
      });

      // Update response store after successful API call
      await dispatch('cosmosResponses/updateBulkResponses', response, {
        root: true,
      });
      return response;
    },
  }),
});
