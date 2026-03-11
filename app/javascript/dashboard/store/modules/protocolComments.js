import types from '../mutation-types';
import ProtocolCommentsAPI from '../../api/protocolComments';
import { throwErrorMessage } from '../utils/api';

/**
 * Estado: comentários organizados por protocolId para evitar mistura:
 * { [protocolId]: Comment[] }
 */
export const state = {
  commentsByProtocol: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
  },
};

export const getters = {
  getCommentsByProtocol: $state => protocolId => {
    return $state.commentsByProtocol[protocolId] ?? [];
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  /**
   * Carrega todos os comentários de um protocolo.
   */
  get: async ({ commit }, protocolId) => {
    commit(types.SET_PROTOCOL_COMMENTS_UI_FLAG, { isFetching: true });
    try {
      const response = await ProtocolCommentsAPI.getAll(protocolId);
      commit(types.SET_PROTOCOL_COMMENTS, {
        protocolId,
        comments: response.data,
      });
    } catch (error) {
      // silencia
    } finally {
      commit(types.SET_PROTOCOL_COMMENTS_UI_FLAG, { isFetching: false });
    }
  },

  /**
   * Cria um comentário, com suporte a arquivos.
   * @param {number}  protocolId
   * @param {Object}  data     - { content, is_private }
   * @param {File[]}  [files]  - arquivos para upload
   */
  create: async ({ commit }, { protocolId, data, files = [] }) => {
    commit(types.SET_PROTOCOL_COMMENTS_UI_FLAG, { isCreating: true });
    try {
      const response = await ProtocolCommentsAPI.create(
        protocolId,
        data,
        files
      );
      commit(types.ADD_PROTOCOL_COMMENT, {
        protocolId,
        comment: response.data,
      });
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_PROTOCOL_COMMENTS_UI_FLAG, { isCreating: false });
    }
  },

  /**
   * Remove um comentário.
   */
  delete: async ({ commit }, { protocolId, commentId }) => {
    commit(types.SET_PROTOCOL_COMMENTS_UI_FLAG, { isDeleting: true });
    try {
      await ProtocolCommentsAPI.delete(protocolId, commentId);
      commit(types.DELETE_PROTOCOL_COMMENT, { protocolId, commentId });
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PROTOCOL_COMMENTS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_PROTOCOL_COMMENTS_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },

  [types.SET_PROTOCOL_COMMENTS]($state, { protocolId, comments }) {
    $state.commentsByProtocol = {
      ...$state.commentsByProtocol,
      [protocolId]: comments,
    };
  },

  [types.ADD_PROTOCOL_COMMENT]($state, { protocolId, comment }) {
    const existing = $state.commentsByProtocol[protocolId] ?? [];
    $state.commentsByProtocol = {
      ...$state.commentsByProtocol,
      [protocolId]: [...existing, comment],
    };
  },

  [types.DELETE_PROTOCOL_COMMENT]($state, { protocolId, commentId }) {
    const existing = $state.commentsByProtocol[protocolId] ?? [];
    $state.commentsByProtocol = {
      ...$state.commentsByProtocol,
      [protocolId]: existing.filter(c => c.id !== commentId),
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
