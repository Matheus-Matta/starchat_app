import { createStore } from 'vuex';

import accounts from './modules/accounts';
import agentBots from './modules/agentBots';
import agentCapacityPolicies from './modules/agentCapacityPolicies';
import agents from './modules/agents';
import assignmentPolicies from './modules/assignmentPolicies';
import articles from './modules/helpCenterArticles';
import attributes from './modules/attributes';
import auditlogs from './modules/auditlogs';
import auth from './modules/auth';
import automations from './modules/automations';
import bulkActions from './modules/bulkActions';
import campaigns from './modules/campaigns';
import cannedResponse from './modules/cannedResponse';
import categories from './modules/helpCenterCategories';
import companies from './modules/companies';
import contactConversations from './modules/contactConversations';
import contactLabels from './modules/contactLabels';
import contactNotes from './modules/contactNotes';
import contacts from './modules/contacts';
import conversationLabels from './modules/conversationLabels';
import conversationMetadata from './modules/conversationMetadata';
import conversationPage from './modules/conversationPage';
import conversations from './modules/conversations';
import conversationSearch from './modules/conversationSearch';
import conversationStats from './modules/conversationStats';
import conversationTypingStatus from './modules/conversationTypingStatus';
import conversationWatchers from './modules/conversationWatchers';
import csat from './modules/csat';
import customRole from './modules/customRole';
import customViews from './modules/customViews';
import dashboardApps from './modules/dashboardApps';
import draftMessages from './modules/draftMessages';
import globalConfig from 'shared/store/globalConfig';
import inboxAssignableAgents from './modules/inboxAssignableAgents';
import inboxes from './modules/inboxes';
import inboxMembers from './modules/inboxMembers';
import integrations from './modules/integrations';
import labels from './modules/labels';
import macros from './modules/macros';
import notifications from './modules/notifications';
import portals from './modules/helpCenterPortals';
import reports from './modules/reports';
import sla from './modules/sla';
import slaReports from './modules/SLAReports';
import summaryReports from './modules/summaryReports';
import teamMembers from './modules/teamMembers';
import teams from './modules/teams';
import userNotificationSettings from './modules/userNotificationSettings';
import webhooks from './modules/webhooks';
import cosmosAssistants from './cosmos/assistant';
import cosmosDocuments from './cosmos/document';
import cosmosResponses from './cosmos/response';
import cosmosInboxes from './cosmos/inboxes';
import cosmosBulkActions from './cosmos/bulkActions';
import copilotThreads from './cosmos/copilotThreads';
import copilotMessages from './cosmos/copilotMessages';
import cosmosScenarios from './cosmos/scenarios';
import cosmosTools from './cosmos/tools';
import cosmosCustomTools from './cosmos/customTools';

import evolution from './modules/channels/evolution';

const plugins = [];

export default createStore({
  modules: {
    accounts,
    agentBots,
    agentCapacityPolicies,
    agents,
    assignmentPolicies,
    articles,
    attributes,
    auditlogs,
    auth,
    automations,
    bulkActions,
    campaigns,
    cannedResponse,
    categories,
    companies,
    contactConversations,
    contactLabels,
    contactNotes,
    contacts,
    conversationLabels,
    conversationMetadata,
    conversationPage,
    conversations,
    conversationSearch,
    conversationStats,
    conversationTypingStatus,
    conversationWatchers,
    csat,
    customRole,
    customViews,
    dashboardApps,
    draftMessages,
    globalConfig,
    inboxAssignableAgents,
    inboxes,
    inboxMembers,
    integrations,
    labels,
    macros,
    notifications,
    portals,
    reports,
    sla,
    slaReports,
    summaryReports,
    teamMembers,
    teams,
    userNotificationSettings,
    webhooks,
    cosmosAssistants,
    cosmosDocuments,
    cosmosResponses,
    cosmosInboxes,
    cosmosBulkActions,
    copilotThreads,
    copilotMessages,
    cosmosScenarios,
    cosmosTools,
    cosmosCustomTools,
    evolution,
  },
  plugins,
});
