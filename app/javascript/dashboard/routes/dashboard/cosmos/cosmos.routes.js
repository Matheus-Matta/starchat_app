import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import { frontendURL } from '../../../helper/URLHelper';

import CosmosPageRouteView from './pages/CosmosPageRouteView.vue';
import AssistantsIndexPage from './pages/AssistantsIndexPage.vue';
import AssistantEmptyStateIndex from './assistants/Index.vue';

import AssistantSettingsIndex from './assistants/settings/Settings.vue';
import AssistantInboxesIndex from './assistants/inboxes/Index.vue';
import AssistantPlaygroundIndex from './assistants/playground/Index.vue';
import AssistantGuardrailsIndex from './assistants/guardrails/Index.vue';
import AssistantGuidelinesIndex from './assistants/guidelines/Index.vue';
import AssistantScenariosIndex from './assistants/scenarios/Index.vue';
import DocumentsIndex from './documents/Index.vue';
import ResponsesIndex from './responses/Index.vue';
import ResponsesPendingIndex from './responses/Pending.vue';
import CustomToolsIndex from './tools/Index.vue';

const meta = {
  permissions: ['administrator', 'agent'],
  featureFlag: FEATURE_FLAGS.COSMOS,
  installationTypes: [INSTALLATION_TYPES.CLOUD, INSTALLATION_TYPES.ENTERPRISE],
};

const metaV2 = {
  permissions: ['administrator', 'agent'],
  featureFlag: FEATURE_FLAGS.COSMOS_V2,
  installationTypes: [INSTALLATION_TYPES.CLOUD, INSTALLATION_TYPES.ENTERPRISE],
};

const assistantRoutes = [
  {
    path: frontendURL('accounts/:accountId/cosmos/:assistantId/faqs'),
    component: ResponsesIndex,
    name: 'cosmos_assistants_responses_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/:assistantId/documents'),
    component: DocumentsIndex,
    name: 'cosmos_assistants_documents_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/:assistantId/tools'),
    component: CustomToolsIndex,
    name: 'cosmos_tools_index',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/:assistantId/scenarios'),
    component: AssistantScenariosIndex,
    name: 'cosmos_assistants_scenarios_index',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/:assistantId/playground'),
    component: AssistantPlaygroundIndex,
    name: 'cosmos_assistants_playground_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/:assistantId/inboxes'),
    component: AssistantInboxesIndex,
    name: 'cosmos_assistants_inboxes_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/:assistantId/faqs/pending'),
    component: ResponsesPendingIndex,
    name: 'cosmos_assistants_responses_pending',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/:assistantId/settings'),
    component: AssistantSettingsIndex,
    name: 'cosmos_assistants_settings_index',
    meta,
  },
  // Settings sub-pages (guardrails and guidelines)
  {
    path: frontendURL(
      'accounts/:accountId/cosmos/:assistantId/settings/guardrails'
    ),
    component: AssistantGuardrailsIndex,
    name: 'cosmos_assistants_guardrails_index',
    meta: metaV2,
  },
  {
    path: frontendURL(
      'accounts/:accountId/cosmos/:assistantId/settings/guidelines'
    ),
    component: AssistantGuidelinesIndex,
    name: 'cosmos_assistants_guidelines_index',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/assistants'),
    component: AssistantEmptyStateIndex,
    name: 'cosmos_assistants_create_index',
    meta: {
      permissions: ['administrator', 'agent'],
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
      ],
    },
  },
  {
    path: frontendURL('accounts/:accountId/cosmos/:navigationPath'),
    component: AssistantsIndexPage,
    name: 'cosmos_assistants_index',
    meta,
  },
];

export const routes = [
  {
    path: frontendURL('accounts/:accountId/cosmos'),
    component: CosmosPageRouteView,
    redirect: to => {
      return {
        name: 'cosmos_assistants_index',
        params: {
          navigationPath: 'cosmos_assistants_responses_index',
          ...to.params,
        },
      };
    },
    children: [...assistantRoutes],
  },
];
