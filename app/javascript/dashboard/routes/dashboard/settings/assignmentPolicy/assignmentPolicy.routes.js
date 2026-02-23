import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import AgentAssignmentIndex from './pages/AgentAssignmentIndexPage.vue';
import AgentAssignmentCreate from './pages/AgentAssignmentCreatePage.vue';
import AgentAssignmentEdit from './pages/AgentAssignmentEditPage.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/assignment-policy'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'agent_assignment_policy_index', params: to.params };
          },
        },
        {
          path: 'assignment',
          name: 'agent_assignment_policy_index',
          component: AgentAssignmentIndex,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: 'assignment/create',
          name: 'agent_assignment_policy_create',
          component: AgentAssignmentCreate,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: 'assignment/edit/:id',
          name: 'agent_assignment_policy_edit',
          component: AgentAssignmentEdit,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
