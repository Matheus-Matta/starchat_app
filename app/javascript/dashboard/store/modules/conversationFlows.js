import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ConversationFlowsAPI from '../../api/conversationFlows';
import { throwErrorMessage } from '../utils/api';
import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getConversationFlows(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getConversationFlowById: _state => id => {
    return _state.records.find(record => record.id === Number(id)) || {};
  },
};

export const actions = {
  get: async function get({ commit }) {
    commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isFetching: true });
    try {
      const response = await ConversationFlowsAPI.get();
      commit(
        types.SET_CONVERSATION_FLOWS,
        response.data.map(f => camelcaseKeys(f))
      );
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isFetching: false });
    }
  },

  create: async function create({ commit }, flowParams) {
    commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isCreating: true });
    try {
      const response = await ConversationFlowsAPI.create(
        snakecaseKeys(flowParams)
      );
      commit(types.ADD_CONVERSATION_FLOW, camelcaseKeys(response.data));
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isCreating: false });
    }
  },

  update: async function update({ commit }, { id, ...flowParams }) {
    commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isUpdating: true });
    try {
      const response = await ConversationFlowsAPI.update(
        id,
        snakecaseKeys(flowParams)
      );
      commit(types.EDIT_CONVERSATION_FLOW, camelcaseKeys(response.data));
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteFlow({ commit }, flowId) {
    commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isDeleting: true });
    try {
      await ConversationFlowsAPI.delete(flowId);
      commit(types.DELETE_CONVERSATION_FLOW, flowId);
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_CONVERSATION_FLOWS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_CONVERSATION_FLOWS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_CONVERSATION_FLOWS]: MutationHelpers.set,
  [types.SET_CONVERSATION_FLOW]: MutationHelpers.setSingleRecord,
  [types.ADD_CONVERSATION_FLOW]: MutationHelpers.create,
  [types.EDIT_CONVERSATION_FLOW]: MutationHelpers.updateAttributes,
  [types.DELETE_CONVERSATION_FLOW]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
