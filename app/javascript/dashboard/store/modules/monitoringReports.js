import * as types from '../mutation-types';
import MonitoringReportsAPI from '../../api/monitoringReports';
import SummaryReportsAPI from '../../api/summaryReports';

const defaultSummary = () => ({
  total_inboxes: 0,
  online_inboxes: 0,
  warning_inboxes: 0,
  offline_inboxes: 0,
  total_agents: 0,
  agents_available: 0,
  agents_busy: 0,
  agents_offline: 0,
  total_active_conversations: 0,
});

export const state = {
  summary: defaultSummary(),
  inboxes: [],
  agents: [],
  agentSummaries: [],
  inboxSummaries: [],
  uiFlags: {
    isFetching: false,
    error: null,
    lastSyncedAt: null,
  },
};

export const getters = {
  getSummary($state) {
    return $state.summary;
  },
  getInboxes($state) {
    return $state.inboxes;
  },
  getAgents($state) {
    return $state.agents;
  },
  getAgentSummaries($state) {
    return $state.agentSummaries;
  },
  getInboxSummaries($state) {
    return $state.inboxSummaries;
  },
  getMonitoringUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  async fetchSnapshot({ commit }) {
    commit(types.default.SET_MONITORING_FETCHING, true);
    commit(types.default.SET_MONITORING_ERROR, null);
    try {
      const response = await MonitoringReportsAPI.getSnapshot();
      commit(types.default.SET_MONITORING_SNAPSHOT, response.data);
    } catch (error) {
      commit(types.default.SET_MONITORING_ERROR, error);
      throw error;
    } finally {
      commit(types.default.SET_MONITORING_FETCHING, false);
    }
  },
  updateAgentPresence({ commit }, presencePayload) {
    commit(types.default.UPDATE_MONITORING_AGENT_PRESENCE, presencePayload);
  },
  async fetchAgentSummaries({ commit }, { since, until } = {}) {
    try {
      const response = await SummaryReportsAPI.getAgentReports({
        since,
        until,
      });
      commit(types.default.SET_MONITORING_AGENT_SUMMARIES, response.data);
    } catch {
      // silent — snapshot data still shows
    }
  },
  async fetchInboxSummaries({ commit }, { since, until } = {}) {
    try {
      const response = await SummaryReportsAPI.getInboxReports({
        since,
        until,
      });
      commit(types.default.SET_MONITORING_INBOX_SUMMARIES, response.data);
    } catch {
      // silent — snapshot data still shows
    }
  },
};

const mergeSummary = payload => ({
  ...defaultSummary(),
  ...(payload || {}),
});

const deriveErrorMessage = error => {
  if (!error) return null;
  return (
    error?.response?.data?.message ||
    error?.message ||
    'Unable to refresh monitoring data'
  );
};

const syncAgentSummary = $state => {
  const counts = $state.agents.reduce(
    (acc, agent) => {
      acc.total += 1;
      if (agent.availability_status === 'online') acc.online += 1;
      else if (agent.availability_status === 'busy') acc.busy += 1;
      else acc.offline += 1;
      return acc;
    },
    { total: 0, online: 0, busy: 0, offline: 0 }
  );

  $state.summary = {
    ...$state.summary,
    total_agents: counts.total,
    agents_available: counts.online,
    agents_busy: counts.busy,
    agents_offline: counts.offline,
  };
};

export const mutations = {
  [types.default.SET_MONITORING_FETCHING]($state, flag) {
    $state.uiFlags.isFetching = flag;
  },
  [types.default.SET_MONITORING_ERROR]($state, error) {
    $state.uiFlags.error = deriveErrorMessage(error);
  },
  [types.default.SET_MONITORING_SNAPSHOT]($state, payload = {}) {
    $state.summary = mergeSummary(payload.summary);
    $state.inboxes = payload.inboxes || [];
    $state.agents = payload.agents || [];
    $state.uiFlags.lastSyncedAt =
      payload.generated_at || new Date().toISOString();
    syncAgentSummary($state);
  },
  [types.default.UPDATE_MONITORING_AGENT_PRESENCE]($state, presence = {}) {
    if (!presence || !$state.agents.length) return;

    $state.agents = $state.agents.map(agent => {
      const availability = presence[agent.id];
      if (!availability) return agent;

      return {
        ...agent,
        availability_status: availability,
      };
    });

    syncAgentSummary($state);
  },
  [types.default.SET_MONITORING_AGENT_SUMMARIES]($state, summaries) {
    $state.agentSummaries = summaries || [];
  },
  [types.default.SET_MONITORING_INBOX_SUMMARIES]($state, summaries) {
    $state.inboxSummaries = summaries || [];
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
