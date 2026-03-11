import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ProtocolPoliciesAPI from '../../api/protocolPolicies';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getProtocolPolicies($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getProtocolPolicy: $state => policyId => {
    const [policy] = $state.records.filter(
      record => record.id === Number(policyId)
    );
    return policy || {};
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_PROTOCOL_POLICIES_UI_FLAG, { isFetching: true });
    try {
      const response = await ProtocolPoliciesAPI.get();
      commit(types.SET_PROTOCOL_POLICIES, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_PROTOCOL_POLICIES_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, policyData) => {
    commit(types.SET_PROTOCOL_POLICIES_UI_FLAG, { isCreating: true });
    try {
      const response = await ProtocolPoliciesAPI.create(policyData);
      commit(types.ADD_PROTOCOL_POLICY, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PROTOCOL_POLICIES_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, ...data }) => {
    commit(types.SET_PROTOCOL_POLICIES_UI_FLAG, { isUpdating: true });
    try {
      const response = await ProtocolPoliciesAPI.update(id, data);
      commit(types.EDIT_PROTOCOL_POLICY, response.data);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PROTOCOL_POLICIES_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_PROTOCOL_POLICIES_UI_FLAG, { isDeleting: true });
    try {
      await ProtocolPoliciesAPI.delete(id);
      commit(types.DELETE_PROTOCOL_POLICY, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PROTOCOL_POLICIES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_PROTOCOL_POLICIES_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.SET_PROTOCOL_POLICIES]: MutationHelpers.set,
  [types.ADD_PROTOCOL_POLICY]: MutationHelpers.create,
  [types.EDIT_PROTOCOL_POLICY]: MutationHelpers.update,
  [types.DELETE_PROTOCOL_POLICY]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
