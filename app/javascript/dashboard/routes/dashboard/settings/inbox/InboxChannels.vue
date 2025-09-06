<script>
import { mapGetters } from 'vuex';
import globalConfigMixin from 'shared/mixins/globalConfigMixin';

export default {
  mixins: [globalConfigMixin],
  computed: {
    ...mapGetters({
      globalConfig: 'globalConfig/get',
    }),
    isEvolutionProvider() {
      return (
        String(this.$route?.query?.provider || '').toLowerCase() === 'evolution'
      );
    },
    createFlowSteps() {
      const base = ['CHANNEL', 'INBOX', 'AGENT', 'FINISH'];

      const steps = [...base];
      if (this.isEvolutionProvider) {
        const insertAfter = steps.indexOf('INBOX');
        steps.splice(insertAfter + 1, 0, 'QRCODE');
      }

      const routes = {
        CHANNEL: 'settings_inbox_new',
        INBOX: 'settings_inboxes_page_channel',
        QRCODE: 'settings_inboxes_qrcode',
        AGENT: 'settings_inboxes_add_agents',
        FINISH: 'settings_inbox_finish',
      };

      return steps.map(step => {
        return {
          title: this.$t(`INBOX_MGMT.CREATE_FLOW.${step}.TITLE`),
          body: this.$t(`INBOX_MGMT.CREATE_FLOW.${step}.BODY`),
          route: routes[step],
        };
      });
    },
    items() {
      return this.createFlowSteps.map(item => ({
        ...item,
        body: this.useInstallationName(
          item.body,
          this.globalConfig.installationName
        ),
      }));
    },
  },
};
</script>

<template>
  <div class="grid grid-cols-1 md:grid-cols-8 overflow-auto h-full">
    <woot-wizard
      class="hidden md:block col-span-2"
      :global-config="globalConfig"
      :items="items"
    />
    <div class="col-span-6">
      <router-view />
    </div>
  </div>
</template>
