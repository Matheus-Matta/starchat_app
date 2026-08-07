// app/javascript/store/modules/channels/evolution.js
import EvolutionChannel from 'dashboard/api/channel/EvolutionChannel';

export default {
  namespaced: true,
  state: () => ({}),
  getters: {},
  actions: {
    async show(_ctx, { id }) {
      const resp = await EvolutionChannel.show(id);
      return resp?.data || resp;
    },
    async connect(_ctx, { id }) {
      const resp = await EvolutionChannel.connect(id);
      return resp?.data || resp;
    },
    async restart(_ctx, { id }) {
      const resp = await EvolutionChannel.restart(id);
      return resp?.data || resp;
    },
    async disconnect(_ctx, { id }) {
      const resp = await EvolutionChannel.disconnect(id);
      return resp?.data || resp;
    },
    async getSettings(_ctx, { id }) {
      const resp = await EvolutionChannel.getSettings(id);
      return resp?.data || resp;
    },
    async updateSettings(_ctx, { id, settings }) {
      const resp = await EvolutionChannel.updateSettings(id, settings);
      return resp?.data || resp;
    },
    async migrateToWhatsapp(_ctx, { id, whatsappChannel }) {
      const resp = await EvolutionChannel.migrateToWhatsapp(
        id,
        whatsappChannel
      );
      return resp?.data || resp;
    },
  },
  mutations: {},
};
