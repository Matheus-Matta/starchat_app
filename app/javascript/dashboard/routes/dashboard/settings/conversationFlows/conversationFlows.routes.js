import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import ConversationFlowIndexPage from './pages/ConversationFlowIndexPage.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/conversation-flows'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'conversation_flows_index',
          component: ConversationFlowIndexPage,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
