<script>
import { onMounted, onBeforeUnmount } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { objectEntries } from '@vueuse/core';

export default {
  name: 'QrCodeStep',
  components: { NextButton },
  data() {
    return {
      qrcodeBase64: '',
      pairingCode: '',
      state: 'connecting',
      error: '',
      isSubscribed: true,
    };
  },
  computed: {
    inboxId() {
      return this.$route.params.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
  },
  mounted() {
    this._onReconnect = () => {
      this.isSubscribed = true;
    };
    this._onDisconnect = () => {
      this.isSubscribed = false;
    };
    emitter.on('WEBSOCKET_RECONNECT', this._onReconnect);
    emitter.on('WEBSOCKET_DISCONNECT', this._onDisconnect);

    this._onQR = p => {
      if (Number(p.inbox_id) != Number(this.inboxId)) return;
      const b64 = String(p.qrcode_base64 || '').trim();
      if (b64) this.qrcodeBase64 = b64;
      this.pairingCode = p.pairing_code || '';
    };
    this._onConn = p => {
      if (Number(p.inbox_id) != Number(this.inboxId)) return;
      if (p.state) this.state = p.state;
      const s = String(this.state).toLowerCase();
      if (s === 'open') {
        this.goToAgents();
      }
    };
    emitter.on('evolution:qrcode_updated', this._onQR);
    emitter.on('evolution:connection_update', this._onConn);
    if (
      this.inbox?.state &&
      String(this.inbox.state).toLowerCase() === 'open'
    ) {
      this.goToAgents();
    }
  },
  beforeUnmount() {
    emitter.off('WEBSOCKET_RECONNECT', this._onReconnect);
    emitter.off('WEBSOCKET_DISCONNECT', this._onDisconnect);
    emitter.off('evolution:qrcode_updated', this._onQR);
    emitter.off('evolution:connection_update', this._onConn);
  },
  methods: {
    goToAgents() {
      this.$router.replace({
        name: 'settings_inboxes_add_agents',
        params: { accountId: this.accountId, inboxId: this.inboxId },
        query: { ...this.$route.query, provider: 'evolution' },
      });
    },
    skip() {
      this.goToAgents();
    },
  },
};
</script>

<template>
  <div
    class="border border-n-weak bg-n-solid-1 rounded-t-lg border-b-0 h-full w-full p-6 overflow-auto"
  >
    <h2 class="text-xl font-semibold text-center mb-6">
      {{ $t('INBOX_MGMT.CREATE_FLOW.QRCODE.TITLE') }}
    </h2>

    <div class="p-4 rounded-lg border border-n-weak bg-n-solid-2 mb-5">
      <h3 class="mb-1 text-sm font-medium text-slate-12" />
      <ul class="text-xs text-slate-11 list-disc pl-4">
        <li>
          {{ $t('INBOX_MGMT.ADD.EVOLUTION_QR.INSTRUCTIONS.ITEM_1') }}
        </li>
        <li>
          {{ $t('INBOX_MGMT.ADD.EVOLUTION_QR.INSTRUCTIONS.ITEM_2') }}
        </li>
        <li>
          {{ $t('INBOX_MGMT.ADD.EVOLUTION_QR.INSTRUCTIONS.ITEM_3') }}
        </li>
      </ul>
      <div class="mt-6 flex flex-col items-center">
        <div
          class="border border-n-weak rounded-lg bg-n-solid-1 p-6 w-full max-w-[540px]"
        >
          <div class="flex flex-col items-center justify-center min-h-72">
            <div v-if="qrcodeBase64" class="flex flex-col items-center">
              <img
                :key="qrcodeBase64"
                :src="qrcodeBase64"
                :alt="$t('INBOX_MGMT.CREATE_FLOW.QRCODE.ALT')"
                class="w-full h-full object-contain"
              />
            </div>
            <div v-else class="text-center opacity-80">
              <woot-loading-indicator />
              <p class="mt-3">
                {{ $t('INBOX_MGMT.CREATE_FLOW.QRCODE.WAITING') }}
              </p>
            </div>
          </div>
        </div>
      </div>
      <div class="w-full mt-6">
        <NextButton
          solid
          blue
          :label="$t('INBOX_MGMT.GENERAL.NEXT')"
          @click="skip"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.min-h-72 {
  min-height: 18rem;
}
</style>
