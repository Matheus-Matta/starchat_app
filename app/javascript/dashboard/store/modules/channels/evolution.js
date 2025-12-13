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
  },
  mutations: {},
};
