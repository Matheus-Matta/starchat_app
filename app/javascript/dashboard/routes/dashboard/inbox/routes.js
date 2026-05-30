import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import InboxListView from './InboxList.vue';
import InboxDetailView from './InboxView.vue';
import InboxEmptyStateView from './InboxEmptyState.vue';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/inbox-view'),
    component: InboxListView,
    children: [
      {
        path: '',
        name: 'inbox_view',
        component: InboxEmptyStateView,
        meta: {
          featureFlag: FEATURE_FLAGS.INBOX_VIEW,
          permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
        },
      },
      {
        path: ':type/:id',
        name: 'inbox_view_conversation',
        component: InboxDetailView,
        meta: {
          featureFlag: FEATURE_FLAGS.INBOX_VIEW,
          permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
        },
      },
    ],
  },
];
