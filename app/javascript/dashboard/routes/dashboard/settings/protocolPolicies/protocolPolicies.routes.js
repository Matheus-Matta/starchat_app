import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

const meta = {
  permissions: ['administrator'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/protocol-policies'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'protocol_policies_wrapper',
          meta,
          redirect: to => ({
            name: 'protocol_policies_list',
            params: to.params,
          }),
        },
        {
          path: 'list',
          name: 'protocol_policies_list',
          meta,
          component: Index,
        },
      ],
    },
  ],
};
