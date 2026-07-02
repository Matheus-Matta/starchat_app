import api from '../../api/whatsappTemplateReports';

const state = {
  records: [],
  isFetching: false,
};

export const getters = {
  getRecords($state) {
    return $state.records;
  },
  isFetching($state) {
    return $state.isFetching;
  },
};

export const actions = {
  async get({ commit }, { inboxId, since, until }) {
    commit('SET_FETCHING', true);
    try {
      const { data } = await api.get({ inboxId, since, until });
      commit('SET_RECORDS', data.data || []);
    } catch {
      commit('SET_RECORDS', []);
    } finally {
      commit('SET_FETCHING', false);
    }
  },
};

export const mutations = {
  SET_RECORDS($state, records) {
    $state.records = records;
  },
  SET_FETCHING($state, value) {
    $state.isFetching = value;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
