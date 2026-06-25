export const generateReportURLParams = ({
  from,
  to,
  businessHours,
  groupBy,
  range,
}) => {
  const params = {};

  // Always include from/to dates
  if (from) params.from = from;
  if (to) params.to = to;

  if (businessHours) params.business_hours = 'true';
  if (groupBy) params.group_by = groupBy;

  // Include range type (last7days, last3months, custom, etc.)
  if (range) params.range = range;

  return params;
};

export const parseReportURLParams = query => {
  const { from, to, business_hours, group_by, range } = query;

  return {
    from: from ? Number(from) : null,
    to: to ? Number(to) : null,
    businessHours: business_hours === 'true',
    groupBy: group_by ? Number(group_by) : null,
    range: range || null,
  };
};

const parseIdListParam = value => {
  if (!value) return [];

  return String(value)
    .split(',')
    .map(Number)
    .filter(id => !Number.isNaN(id));
};

const parseStringListParam = value => {
  if (!value) return [];

  return String(value)
    .split(',')
    .map(item => item.trim())
    .filter(Boolean);
};

// Parse filter params from URL. agent_id/inbox_id/team_id/label support multiple
// comma-separated values (e.g. ?agent_id=3,7) for the reports multi-select filters;
// sla_policy_id/rating stay single-valued.
export const parseFilterURLParams = query => {
  return {
    agent_id: parseIdListParam(query.agent_id),
    inbox_id: parseIdListParam(query.inbox_id),
    team_id: parseIdListParam(query.team_id),
    sla_policy_id: query.sla_policy_id ? Number(query.sla_policy_id) : null,
    label: parseStringListParam(query.label),
    rating: query.rating ? Number(query.rating) : null,
  };
};

// Generate filter URL params (only include non-empty values)
export const generateFilterURLParams = filters => {
  const params = {};
  if (filters.agent_id?.length) params.agent_id = filters.agent_id.join(',');
  if (filters.inbox_id?.length) params.inbox_id = filters.inbox_id.join(',');
  if (filters.team_id?.length) params.team_id = filters.team_id.join(',');
  if (filters.sla_policy_id) params.sla_policy_id = filters.sla_policy_id;
  if (filters.label?.length) params.label = filters.label.join(',');
  if (filters.rating) params.rating = filters.rating;
  return params;
};

// Parse the comma-separated list of extra entity ids selected for comparison
// (Reports overview multi-select, e.g. ?compare_ids=4,7)
export const parseCompareIdsParam = query =>
  parseIdListParam(query.compare_ids);

export const generateCompareIdsParam = ids => {
  return ids && ids.length ? { compare_ids: ids.join(',') } : {};
};

// Merge date range and filter params for complete URL
export const generateCompleteURLParams = ({
  from,
  to,
  range,
  filters = {},
}) => {
  const dateParams = generateReportURLParams({ from, to, range });
  const filterParams = generateFilterURLParams(filters);
  return { ...dateParams, ...filterParams };
};
