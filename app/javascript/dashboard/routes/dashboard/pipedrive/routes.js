/* eslint-disable arrow-body-style */
import { frontendURL } from '../../../helper/URLHelper';

const DealsIndex = () => import('./pages/DealsIndex.vue');
const LeadsIndex = () => import('./pages/LeadsIndex.vue');
const ActivitiesIndex = () => import('./pages/ActivitiesIndex.vue');

const commonMeta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/pipedrive/deals'),
    name: 'pipedrive_deals_index',
    component: DealsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/pipedrive/leads'),
    name: 'pipedrive_leads_index',
    component: LeadsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/pipedrive/activities'),
    name: 'pipedrive_activities_index',
    component: ActivitiesIndex,
    meta: commonMeta,
    component: ActivitiesIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/pipedrive/deals/segments/:filterId'),
    name: 'pipedrive_deals_filters',
    component: DealsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/pipedrive/leads/segments/:filterId'),
    name: 'pipedrive_leads_filters',
    component: LeadsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL(
      'accounts/:accountId/pipedrive/activities/segments/:filterId'
    ),
    name: 'pipedrive_activities_filters',
    component: ActivitiesIndex,
    meta: commonMeta,
  },
];
