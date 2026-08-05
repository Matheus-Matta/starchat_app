/* global axios */
import ApiClient from './ApiClient';

const getTimeOffset = () => -new Date().getTimezoneOffset() / 60;

class ReportsAPI extends ApiClient {
  constructor() {
    super('reports', { accountScoped: true, apiVersion: 'v2' });
  }

  getReports({
    metric,
    from,
    to,
    type = 'account',
    id,
    agentIds,
    teamIds,
    inboxIds,
    groupBy,
    businessHours,
    status,
  }) {
    return axios.get(`${this.url}`, {
      params: {
        metric,
        since: from,
        until: to,
        type,
        id,
        agent_ids: agentIds,
        team_ids: teamIds,
        inbox_ids: inboxIds,
        group_by: groupBy,
        business_hours: businessHours,
        status: status || undefined,
        timezone_offset: getTimeOffset(),
      },
    });
  }

  getSummary(
    since,
    until,
    // eslint-disable-next-line default-param-last
    type = 'account',
    id,
    groupBy,
    businessHours,
    status,
    // combined dimensions (e.g. Conversation report filter) - omitted by callers
    // that still use the single `type`/`id` dimension (e.g. Overview/CSAT/SLA)
    { agentIds, teamIds, inboxIds } = {}
  ) {
    return axios.get(`${this.url}/summary`, {
      params: {
        since,
        until,
        type,
        id,
        agent_ids: agentIds,
        team_ids: teamIds,
        inbox_ids: inboxIds,
        group_by: groupBy,
        business_hours: businessHours,
        status: status || undefined,
        timezone_offset: getTimeOffset(),
      },
    });
  }

  getConversationMetric(type = 'account', page = 1) {
    return axios.get(`${this.url}/conversations`, {
      params: {
        type,
        page,
      },
    });
  }

  getAgentReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/agents`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getAgentConversationsReport({
    agentId,
    from: since,
    to: until,
    businessHours,
  }) {
    return axios.get(`${this.url}/agents/${agentId}/conversations`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getConversationsSummaryReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/conversations_summary`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getConversationTrafficCSV({ daysBefore = 6 } = {}) {
    return axios.get(`${this.url}/conversation_traffic`, {
      params: { timezone_offset: getTimeOffset(), days_before: daysBefore },
    });
  }

  getLabelReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/labels`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getInboxReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/inboxes`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getTeamReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/teams`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getBotMetrics({ from, to } = {}) {
    return axios.get(`${this.url}/bot_metrics`, {
      params: { since: from, until: to },
    });
  }

  getBotSummary({ from, to, groupBy, businessHours } = {}) {
    return axios.get(`${this.url}/bot_summary`, {
      params: {
        since: from,
        until: to,
        type: 'account',
        group_by: groupBy,
        business_hours: businessHours,
      },
    });
  }
}

export default new ReportsAPI();
