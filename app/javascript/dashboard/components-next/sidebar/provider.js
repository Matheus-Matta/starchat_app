import { inject, provide } from 'vue';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useRouter } from 'vue-router';

const SidebarControl = Symbol('SidebarControl');

export function useSidebarContext() {
  const context = inject(SidebarControl, null);
  if (context === null) {
    throw new Error(`Component is missing a parent <Sidebar /> component.`);
  }

  const router = useRouter();

  const { shouldShow } = usePolicy();

  const resolvePath = to => {
    if (!to) return '/';
    try {
      return router.resolve(to)?.path || '/';
    } catch (error) {
      console.warn('Failed to resolve path:', to, error);
      return '/';
    }
  };

  // Helper to find route definition by name without resolving
  const findRouteByName = name => {
    try {
      const routes = router.getRoutes();
      return routes.find(route => route.name === name);
    } catch (error) {
      console.warn('Failed to find route by name:', name, error);
      return undefined;
    }
  };

  const resolvePermissions = to => {
    if (!to) return [];

    try {
      // If navigationPath param exists, get the target route definition
      if (to.params?.navigationPath) {
        const targetRoute = findRouteByName(to.params.navigationPath);
        return targetRoute?.meta?.permissions ?? [];
      }

      return router.resolve(to)?.meta?.permissions ?? [];
    } catch (error) {
      console.warn('Failed to resolve permissions:', to, error);
      return [];
    }
  };

  const resolveFeatureFlag = to => {
    if (!to) return '';

    try {
      // If navigationPath param exists, get the target route definition
      if (to.params?.navigationPath) {
        const targetRoute = findRouteByName(to.params.navigationPath);
        return targetRoute?.meta?.featureFlag || '';
      }

      return router.resolve(to)?.meta?.featureFlag || '';
    } catch (error) {
      console.warn('Failed to resolve feature flag:', to, error);
      return '';
    }
  };

  const resolveInstallationType = to => {
    if (!to) return [];

    try {
      // If navigationPath param exists, get the target route definition
      if (to.params?.navigationPath) {
        const targetRoute = findRouteByName(to.params.navigationPath);
        return targetRoute?.meta?.installationTypes || [];
      }

      return router.resolve(to)?.meta?.installationTypes || [];
    } catch (error) {
      console.warn('Failed to resolve installation type:', to, error);
      return [];
    }
  };

  const isAllowed = to => {
    try {
      const permissions = resolvePermissions(to);
      const featureFlag = resolveFeatureFlag(to);
      const installationType = resolveInstallationType(to);
      return shouldShow(featureFlag, permissions, installationType);
    } catch (error) {
      console.error('Erro em isAllowed / policy:', error);
      return true;
    }
  };

  return {
    ...context,
    resolvePath,
    resolvePermissions,
    resolveFeatureFlag,
    isAllowed,
  };
}

export function provideSidebarContext(context) {
  provide(SidebarControl, context);
}
