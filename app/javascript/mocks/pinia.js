// Lightweight Pinia mock to satisfy unit tests in CI/editor environments
export function defineStore(id, options) {
  // Return a factory that creates a mock store instance
  return function useStore() {
    // Initialize state from Pinia-like options
    const initialState = typeof options.state === 'function' ? options.state() : options.state;
    // shallow clone to avoid mutating shared objects
    const store = {
      ...initialState,
    };

    // Getter: getRecords -> sorted by id desc
    Object.defineProperty(store, 'getRecords', {
      get() {
        const arr = (store.records || []).slice();
        return arr.sort((a, b) => (b.id ?? 0) - (a.id ?? 0));
      }
    });

    // Getter: getRecord(id) -> returns object or {}
    store.getRecord = (id) => {
      return (store.records || []).find(r => r.id === Number(id)) || {};
    };

    // Basic getters exposing state
    Object.defineProperty(store, 'getUIFlags', {
      get() {
        return store.uiFlags;
      }
    });
    Object.defineProperty(store, 'getMeta', {
      get() {
        return store.meta;
      }
    });

    // Actions
    store.setUIFlag = data => {
      store.uiFlags = { ...store.uiFlags, ...data };
    };
    store.setMeta = meta => {
      store.meta = {
        ...store.meta,
        totalCount: Number(meta.total_count ?? meta.totalCount ?? 0),
        page: Number(meta.page ?? 1),
      };
    };

    // CRUD actions using provided API
    store.get = async (params) => {
      if (!options.API || !options.API.get) return [];
      const resp = await options.API.get(params);
      const data = resp?.data?.payload ?? resp?.data ?? [];
      if (Array.isArray(data)) store.records = data;
      if (resp?.data?.meta) {
        const m = resp.data.meta;
        store.meta = { totalCount: m.total_count ?? m.totalCount ?? 0, page: m.page ?? 1 };
      }
      return data;
    };
    store.show = async (id) => {
      if (!options.API || !options.API.show) return {};
      const resp = await options.API.show(id);
      const data = resp?.data?.payload ?? resp?.data ?? resp?.data;
      if (data) {
        const idx = (store.records || []).findIndex(r => r.id === data.id);
        if (idx >= 0) store.records[idx] = data; else (store.records ||= []).push(data);
      }
      return data;
    };
    store.create = async (obj) => {
      if (!options.API || !options.API.create) return {};
      const resp = await options.API.create(obj);
      const data = resp?.data?.payload ?? resp?.data ?? resp?.data;
      if (data) (store.records ||= []).push(data);
      return data;
    };
    store.update = async (payload) => {
      if (!options.API || !options.API.update) return {};
      const resp = await options.API.update(payload.id, payload);
      const data = resp?.data?.payload ?? resp?.data ?? resp?.data;
      if (data) {
        const idx = (store.records || []).findIndex(r => r.id === data.id);
        if (idx >= 0) store.records[idx] = data; else (store.records ||= []).push(data);
      }
      return data;
    };
    store.delete = async (id) => {
      if (!options.API || !options.API.delete) return id;
      await options.API.delete(id);
      store.records = (store.records || []).filter(r => r.id !== id);
      return id;
    };

    // Merge custom getters if provided
    if (options.getters) {
      Object.entries(options.getters).forEach(([k, fn]) => {
        // don't redefine existing properties (e.g., built-in getters)
        if (Object.prototype.hasOwnProperty.call(store, k)) return;
        Object.defineProperty(store, k, {
          get: () => fn(store),
          configurable: true,
        });
      });
    }

    // Merge additional actions defined by user
    if (options.actions) {
      const extra = typeof options.actions === 'function' ? options.actions() : options.actions;
      Object.assign(store, extra || {});
    }

    return store;
  };
}

export function createPinia() {
  return {};
}

export function storeToRefs(store) {
  const refs = {};
  Object.keys(store).forEach(key => {
    if (typeof store[key] !== 'function') {
      refs[key] = {
        get value() { return store[key]; },
        set value(v) { store[key] = v; },
      };
    }
  });
  return refs;
}

let _activePinia = null;
export function setActivePinia(pin) { _activePinia = pin; }
export function getActivePinia() { return _activePinia; }
