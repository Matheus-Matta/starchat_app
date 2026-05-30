import agentMgmt from './agentMgmt.json';
import cannedMgmt from './cannedMgmt.json';
import chatlist from './chatlist.json';
import contact from './contact.json';
import conversation from './conversation.json';
import generalSettings from './generalSettings.json';
import inboxMgmt from './inboxMgmt.json';
import integrations from './integrations.json';
import labelsMgmt from './labelsMgmt.json';
import login from './login.json';
import report from './report.json';
import resetPassword from './resetPassword.json';
import setNewPassword from './setNewPassword.json';
import settings from './settings.json';
import signup from './signup.json';
import webhooks from './webhooks.json';

export default {
  ...agentMgmt,
  ...cannedMgmt,
  ...chatlist,
  ...contact,
  ...conversation,
  ...generalSettings,
  ...inboxMgmt,
  ...integrations,
  ...labelsMgmt,
  ...login,
  ...report,
  ...resetPassword,
  ...setNewPassword,
  ...settings,
  ...signup,
  ...webhooks,
};
