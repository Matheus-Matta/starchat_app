/* global axios */
import ApiClient from './ApiClient';

class ProtocolCommentsAPI extends ApiClient {
  constructor() {
    super('protocols', { accountScoped: true });
  }

  /**
   * Lista todos os comentários de um protocolo.
   */
  getAll(protocolId) {
    return axios.get(`${this.url}/${protocolId}/protocol_comments`);
  }

  /**
   * Cria um comentário, opcionalmente com arquivos anexados.
   * @param {number}   protocolId
   * @param {Object}   data        - { content, is_private }
   * @param {File[]}   [files=[]]  - arquivos para anexar (multipart)
   */
  create(protocolId, data, files = []) {
    if (files.length > 0) {
      const formData = new FormData();
      formData.append('protocol_comment[content]', data.content);
      formData.append('protocol_comment[is_private]', data.is_private ?? false);
      files.forEach(file => formData.append('files[]', file));
      return axios.post(
        `${this.url}/${protocolId}/protocol_comments`,
        formData,
        { headers: { 'Content-Type': 'multipart/form-data' } }
      );
    }

    return axios.post(`${this.url}/${protocolId}/protocol_comments`, {
      protocol_comment: data,
    });
  }

  /**
   * Remove um comentário.
   */
  delete(protocolId, commentId) {
    return axios.delete(
      `${this.url}/${protocolId}/protocol_comments/${commentId}`
    );
  }
}

export default new ProtocolCommentsAPI();
