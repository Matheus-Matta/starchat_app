// src/api/integrations/typebot.js
import ApiClient from 'dashboard/apiClient'; // o mesmo client que o projeto usa (axios)

const base = accountId => `/api/v1/accounts/${accountId}/integrations`;

export const listIntegrationApps = accountId =>
  ApiClient.get(`${base(accountId)}/apps`);

export const listHooks = (accountId, { appId = 'typebot' } = {}) =>
  ApiClient.get(`${base(accountId)}/hooks`, { params: { app_id: appId } });

export const deleteHook = (accountId, hookId) =>
  ApiClient.delete(`${base(accountId)}/hooks/${hookId}`);

export const createTypebotHook = (accountId, payload) =>
  ApiClient.post(`${base(accountId)}/typebot/create`, payload);

export const updateTypebotHook = (accountId, payload) =>
  ApiClient.put(`${base(accountId)}/typebot/update`, payload);

export const sendTypebotMessage = (accountId, payload) =>
  ApiClient.post(`${base(accountId)}/typebot/send_message`, payload);

export const listInboxes = accountId =>
  ApiClient.get(`/api/v1/accounts/${accountId}/inboxes`);
