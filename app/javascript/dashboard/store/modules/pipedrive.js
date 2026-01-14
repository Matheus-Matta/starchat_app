/* eslint-disable no-param-reassign */
import PipedriveAPI from '../../api/pipedrive';

const state = {
  records: {
    deals: [],
    leads: [],
    activities: [],
  },
  meta: {
    deals: { count: 0, currentPage: 1 },
    leads: { count: 0, currentPage: 1 },
    activities: { count: 0, currentPage: 1 },
  },
  uiFlags: {
    isFetching: false,
    isFetchingDeals: false,
    isFetchingLeads: false,
    isFetchingActivities: false,
  },
};

const getters = {
  getDeals: $state => $state.records.deals,
  getLeads: $state => $state.records.leads,
  getActivities: $state => $state.records.activities,
  getMeta: $state => $state.meta,
  getUIFlags: $state => $state.uiFlags,
};

const actions = {
  async getDeals({ commit }, params = {}) {
    console.log('[Pipedrive Store] getDeals params:', params);
    commit('SET_UI_FLAG', {
      isFetchingDeals: true,
      isFetching: true,
      error: null,
    });
    try {
      const response = await PipedriveAPI.getDeals(params);
      console.log('[Pipedrive Store] getDeals success:', response.data);
      commit('SET_DEALS', response.data);
    } catch (error) {
      console.error('[Pipedrive Store] getDeals error:', error);
      commit('SET_UI_FLAG', {
        isFetchingDeals: false,
        isFetching: false,
        error: error.response?.data?.error || error.message,
      });
    } finally {
      commit('SET_UI_FLAG', { isFetchingDeals: false, isFetching: false });
    }
  },
  async getLeads({ commit }, params = {}) {
    console.log('[Pipedrive Store] getLeads params:', params);
    commit('SET_UI_FLAG', {
      isFetchingLeads: true,
      isFetching: true,
      error: null,
    });
    try {
      const response = await PipedriveAPI.getLeads(params);
      console.log('[Pipedrive Store] getLeads success:', response.data);
      commit('SET_LEADS', response.data);
    } catch (error) {
      console.error('[Pipedrive Store] getLeads error:', error);
      commit('SET_UI_FLAG', {
        isFetchingLeads: false,
        isFetching: false,
        error: error.response?.data?.error || error.message,
      });
    } finally {
      commit('SET_UI_FLAG', { isFetchingLeads: false, isFetching: false });
    }
  },
  async getActivities({ commit }, params = {}) {
    console.log('[Pipedrive Store] getActivities params:', params);
    commit('SET_UI_FLAG', {
      isFetchingActivities: true,
      isFetching: true,
      error: null,
    });
    try {
      const response = await PipedriveAPI.getActivities(params);
      console.log('[Pipedrive Store] getActivities success:', response.data);
      commit('SET_ACTIVITIES', response.data);
    } catch (error) {
      console.error('[Pipedrive Store] getActivities error:', error);
      commit('SET_UI_FLAG', {
        isFetchingActivities: false,
        isFetching: false,
        error: error.response?.data?.error || error.message,
      });
    } finally {
      commit('SET_UI_FLAG', { isFetchingActivities: false, isFetching: false });
    }
  },
};

const mutations = {
  SET_UI_FLAG($state, uiFlags) {
    $state.uiFlags = { ...$state.uiFlags, ...uiFlags };
  },
  SET_DEALS($state, data) {
    $state.records.deals = data.payload || [];
    $state.meta.deals = data.meta || {};
  },
  SET_LEADS($state, data) {
    $state.records.leads = data.payload || [];
    $state.meta.leads = data.meta || {};
  },
  SET_ACTIVITIES($state, data) {
    $state.records.activities = data.payload || [];
    $state.meta.activities = data.meta || {};
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
