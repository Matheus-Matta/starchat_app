import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ProtocolsAPI from '../../api/protocols';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  meta: {
    currentPage: 1,
    totalPages: 1,
    totalCount: 0,
  },
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isClosing: false,
    isReopening: false,
  },
};

export const getters = {
  getProtocols($state) {
    return $state.records;
  },
  getMeta($state) {
    return $state.meta;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  /**
   * Retorna um protocolo por id.
   */
  getProtocolById: $state => id => {
    return $state.records.find(r => r.id === Number(id)) || null;
  },
  /**
   * Retorna todos os protocolos abertos de um contato.
   */
  getOpenProtocolsForContact: $state => contactId => {
    return $state.records.filter(
      r => r.contact?.id === Number(contactId) && r.status === 'open'
    );
  },
};

export const actions = {
  /**
   * Busca um protocolo específico por ID e atualiza o estado local.
   */
  show: async ({ commit }, id) => {
    try {
      const response = await ProtocolsAPI.show(id);
      commit(types.EDIT_PROTOCOL, response.data);
      return response.data;
    } catch (error) {
      // silencia — pode não estar carregado ainda
    }
    return null;
  },

  /**
   * Busca lista de protocolos.
   * @param {Object} params - { contact_id, protocol_policy_id, status, q, page }
   */
  get: async ({ commit }, params = {}) => {
    commit(types.SET_PROTOCOLS_UI_FLAG, { isFetching: true });
    try {
      const response = await ProtocolsAPI.get(params);
      commit(types.SET_PROTOCOLS, response.data.data ?? []);
      commit(types.SET_PROTOCOLS_META, response.data.meta ?? {});
    } catch (error) {
      // silencia erros de rede temporários
    } finally {
      commit(types.SET_PROTOCOLS_UI_FLAG, { isFetching: false });
    }
  },

  /**
   * Cria protocolo manualmente.
   */
  create: async ({ commit }, data) => {
    commit(types.SET_PROTOCOLS_UI_FLAG, { isCreating: true });
    try {
      const response = await ProtocolsAPI.create({ protocol: data });
      commit(types.ADD_PROTOCOL, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_PROTOCOLS_UI_FLAG, { isCreating: false });
    }
  },

  /**
   * Atualiza motivo / descrição / problema do protocolo.
   */
  update: async ({ commit }, { id, ...data }) => {
    commit(types.SET_PROTOCOLS_UI_FLAG, { isUpdating: true });
    try {
      const response = await ProtocolsAPI.update(id, { protocol: data });
      commit(types.EDIT_PROTOCOL, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_PROTOCOLS_UI_FLAG, { isUpdating: false });
    }
  },

  /**
   * Arquiva o protocolo (soft delete).
   */
  delete: async ({ commit }, id) => {
    commit(types.SET_PROTOCOLS_UI_FLAG, { isDeleting: true });
    try {
      await ProtocolsAPI.delete(id);
      commit(types.DELETE_PROTOCOL, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PROTOCOLS_UI_FLAG, { isDeleting: false });
    }
  },

  /**
   * Encerra um protocolo (status → closed).
   */
  close: async ({ commit }, id) => {
    commit(types.SET_PROTOCOLS_UI_FLAG, { isClosing: true });
    try {
      const response = await ProtocolsAPI.close(id);
      commit(types.EDIT_PROTOCOL, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_PROTOCOLS_UI_FLAG, { isClosing: false });
    }
  },

  /**
   * Reabre um protocolo (status → open).
   */
  reopen: async ({ commit }, id) => {
    commit(types.SET_PROTOCOLS_UI_FLAG, { isReopening: true });
    try {
      const response = await ProtocolsAPI.reopen(id);
      commit(types.EDIT_PROTOCOL, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_PROTOCOLS_UI_FLAG, { isReopening: false });
    }
  },
};

export const mutations = {
  [types.SET_PROTOCOLS_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },

  [types.SET_PROTOCOLS_META]($state, meta) {
    $state.meta = {
      currentPage: meta.current_page ?? 1,
      totalPages: meta.total_pages ?? 1,
      totalCount: meta.total_count ?? 0,
    };
  },

  [types.SET_PROTOCOLS]: MutationHelpers.set,
  [types.ADD_PROTOCOL]: MutationHelpers.create,

  /**
   * Upsert: atualiza o registro se existir, cria se não existir.
   * Necessário para o action `show` que pode retornar um protocolo ainda não na lista.
   */
  [types.EDIT_PROTOCOL]($state, record) {
    const idx = $state.records.findIndex(r => r.id === record.id);
    if (idx !== -1) {
      $state.records[idx] = { ...$state.records[idx], ...record };
    } else {
      $state.records.push(record);
    }
  },

  [types.DELETE_PROTOCOL]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
