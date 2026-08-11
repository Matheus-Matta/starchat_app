/**
 * The support widget on the dashboard is injected by whatever snippet an admin pasted
 * into DASHBOARD_SCRIPTS. That may be this product's SDK, which defines
 * window.$starchats, or a stock upstream embed pointing at another instance, which only
 * defines window.$chatwoot. Resolve at call time and accept either, so the support
 * button keeps working regardless of which snippet is configured.
 */
export const getSupportWidget = () => window.$starchats || window.$chatwoot;
