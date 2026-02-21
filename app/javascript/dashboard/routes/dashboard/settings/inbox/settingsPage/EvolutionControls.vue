<script>
import { emitter } from 'shared/helpers/mitt';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import WootSwitch from 'dashboard/components-next/switch/Switch.vue';

export default {
  name: 'EvolutionControls',
  components: { NextButton, WootSwitch },
  props: {
    inbox: { type: Object, default: () => ({}) },
  },
  data() {
    return {
      // UI/estado connection
      state: 'disconnected',
      qrcodeBase64: '',
      pairingCode: '',
      isSubscribed: true,
      isBusy: false,
      waitingQR: false,
      showQRPanel: false,

      // channel
      channelLoading: false,
      channelError: '',

      // settings
      loadingSettings: false,
      isUpdating: false,
      settings: {
        rejectCall: false,
        msgCall: '',
        groupsIgnore: false,
        alwaysOnline: false,
        readMessages: false,
        readStatus: false,
        syncFullHistory: false,
        syncContactName: false,
      },
    };
  },
  computed: {
    accountId() {
      return this.$store?.getters?.getCurrentAccountId;
    },
    stateBadge() {
      const s = String(this.state || '').toLowerCase();
      const map = {
        connecting: {
          bg: 'bg-n-amber-3',
          dot: 'bg-n-amber-9',
          text: 'text-n-amber-11',
          i18n: 'CONNECTING',
        },
        connected: {
          bg: 'bg-n-teal-3',
          dot: 'bg-n-teal-9',
          text: 'text-n-teal-11',
          i18n: 'OPEN',
        },
        open: {
          bg: 'bg-n-teal-3',
          dot: 'bg-n-teal-9',
          text: 'text-n-teal-11',
          i18n: 'OPEN',
        },
        disconnected: {
          bg: 'bg-n-gray-3',
          dot: 'bg-n-gray-9',
          text: 'text-n-gray-11',
          i18n: 'DISCONNECTED',
        },
        close: {
          bg: 'bg-n-gray-3',
          dot: 'bg-n-gray-9',
          text: 'text-n-gray-11',
          i18n: 'DISCONNECTED',
        },
      };
      return map[s] || map.disconnected;
    },
    stateI18nLabel() {
      return this.$t('INBOX_MGMT.ADD.EVOLUTION.STATES.' + this.stateBadge.i18n);
    },
    isConnected() {
      return ['open', 'connected'].includes(
        String(this.state || '').toLowerCase()
      );
    },
    isDisconnected() {
      return ['disconnected', 'close'].includes(
        String(this.state || '').toLowerCase()
      );
    },
    isConnecting() {
      return ['connecting', 'qrcode', 'pairing'].includes(
        String(this.state || '').toLowerCase()
      );
    },
  },
  watch: {
    state(newVal) {
      const s = String(newVal).toLowerCase();
      if (s === 'connected' || s === 'open') {
        this.showQRPanel = false;
        this.waitingQR = false;
        this.fetchSettings(); // Busca settings ao conectar
      }
    },
    'inbox.channel_id': {
      immediate: false,
      handler() {
        this.fetchChannel();
      },
    },
  },
  mounted() {
    if (this.inbox && this.inbox.state) this.state = this.inbox.state;

    this.fetchChannel();

    this.handleSocketReconnect = () => {
      this.isSubscribed = true;
    };
    this.handleSocketDisconnect = () => {
      this.isSubscribed = false;
    };
    emitter.on('WEBSOCKET_RECONNECT', this.handleSocketReconnect);
    emitter.on('WEBSOCKET_DISCONNECT', this.handleSocketDisconnect);
    this.handleQRUpdate = p => {
      if (Number(p.inbox_id) !== Number(this.inbox?.id)) return;
      const b64 = String(p.qrcode_base64 || '').trim();
      if (b64) {
        this.qrcodeBase64 = b64;
        this.waitingQR = false;
      }
      this.pairingCode = p.pairing_code || '';
    };
    this.handleConnectionUpdate = p => {
      if (Number(p.inbox_id) !== Number(this.inbox?.id)) return;
      if (p.state) this.state = p.state;
      if (this.isConnected) {
        this.waitingQR = false;
        this.qrcodeBase64 = '';
        this.pairingCode = '';
        this.fetchSettings();
      }
    };

    emitter.on('evolution:qrcode_updated', this.handleQRUpdate);
    emitter.on('evolution:connection_update', this.handleConnectionUpdate);
  },
  beforeUnmount() {
    emitter.off('WEBSOCKET_RECONNECT', this.handleSocketReconnect);
    emitter.off('WEBSOCKET_DISCONNECT', this.handleSocketDisconnect);
    emitter.off('evolution:qrcode_updated', this.handleQRUpdate);
    emitter.off('evolution:connection_update', this.handleConnectionUpdate);
  },
  methods: {
    async fetchChannel() {
      const cid = this.inbox?.channel_id;
      if (!cid) return;

      this.channelLoading = true;
      this.channelError = '';
      this.channel = null;

      try {
        const res = await this.$store.dispatch('evolution/show', { id: cid });
        const ch = res?.channel || res?.data || res || null;

        this.channel = ch;
        if (ch?.state) this.state = ch.state;
        if (this.isConnected) this.fetchSettings();
      } catch (e) {
        // console.error('[EvolutionControls] fetchChannel erro:', e);
        this.channelError =
          e?.message || 'Não foi possível carregar o canal (Evolution).';
      } finally {
        this.channelLoading = false;
      }
    },
    async fetchSettings() {
      if (!this.channel?.id) return;
      this.loadingSettings = true;
      try {
        const data = await this.$store.dispatch('evolution/getSettings', {
          id: this.channel.id,
        });

        // Mescla com defaults para garantir que chaves existam
        if (data) {
          this.settings = { ...this.settings, ...data };
          this.settings.groupsIgnore = true;
          this.settings.syncFullHistory = false;
        }
      } catch (e) {
        // fetchSettings failed silenty
      } finally {
        this.loadingSettings = false;
      }
    },
    async updateSettings() {
      if (!this.channel?.id) return;

      this.isUpdating = true;
      this.settings.groupsIgnore = true;
      this.settings.syncFullHistory = false;
      try {
        await this.$store.dispatch('evolution/updateSettings', {
          id: this.channel.id,
          settings: this.settings,
        });
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (e) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdating = false;
      }
    },
    async onConnect() {
      if (!this.channel?.id) return;
      this.qrcodeBase64 = '';
      this.pairingCode = '';
      this.isBusy = true;
      this.showQRPanel = true;
      this.waitingQR = true;
      if (!this.state || this.isDisconnected) this.state = 'connecting';

      try {
        const resp = await this.$store.dispatch('evolution/connect', {
          id: this.channel.id,
        });
        const payload = resp?.data || resp || {};
        const newState = payload.state || payload.status;
        const qrB64 = payload.qrcode_base64 || payload.base64 || payload.qr;
        const pairing = payload.pairing_code || payload.pairingCode;

        if (newState) this.state = newState;
        if (qrB64) {
          this.qrcodeBase64 = qrB64;
          this.pairingCode = pairing || '';
          this.waitingQR = false;
        }
      } catch (e) {
        // console.error('[Evolution] connect erro:', e);
        this.state = 'error';
        this.waitingQR = false;
      } finally {
        this.isBusy = false;
      }
    },

    async onDisconnect() {
      if (!this.channel?.id) return;

      this.isBusy = true;
      try {
        await this.$store.dispatch('evolution/disconnect', {
          id: this.channel.id,
        });
        this.state = 'disconnected';
        this.showQRPanel = false;
        this.waitingQR = false;
        this.qrcodeBase64 = '';
        this.pairingCode = '';
      } catch (e) {
        // console.error('[Evolution] disconnect erro:', e);
      } finally {
        this.isBusy = false;
      }
    },

    async onRestart() {
      if (!this.channel?.id) return;
      this.qrcodeBase64 = '';
      this.pairingCode = '';
      this.isBusy = true;
      this.showQRPanel = true;
      this.waitingQR = true;
      this.state = 'connecting';

      try {
        const resp = await this.$store.dispatch('evolution/restart', {
          id: this.channel.id,
        });
        const payload = resp?.data || resp || {};
        const newState = payload.state || payload.status;
        const qrB64 = payload.qrcode_base64 || payload.base64 || payload.qr;
        const pairing = payload.pairing_code || payload.pairingCode;

        if (newState) this.state = newState;
        if (qrB64) {
          this.qrcodeBase64 = qrB64;
          this.pairingCode = pairing || '';
          this.waitingQR = false;
        }
      } catch (e) {
        // console.error('[Evolution] restart erro:', e);
        this.state = 'error';
        this.waitingQR = false;
      } finally {
        this.isBusy = false;
      }
    },
  },
};
</script>

<template>
  <div class="gap-4 pt-8 mx-8">
    <div
      class="px-5 py-5 space-y-6 rounded-xl border shadow-sm border-n-weak bg-n-solid-2"
    >
      <div
        class="flex flex-col gap-5 justify-between items-start w-full md:flex-row"
      >
        <div>
          <span class="text-base font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.TITLE') }}
          </span>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.QR.INSTRUCTION') }}
          </p>
        </div>

        <div class="flex items-center gap-2 flex-shrink-0">
          <!-- Status Badge -->
          <span
            class="flex flex-row items-center py-0.5 px-2 rounded text-xs mr-2"
            :class="stateBadge.bg"
          >
            <span
              class="h-1 w-1 rounded-full mr-1 rtl:mr-0 rtl:ml-0"
              :class="stateBadge.dot"
            />
            <span class="text-xs" :class="stateBadge.text">
              {{ stateI18nLabel }}
            </span>
          </span>

          <!-- Actions -->
          <NextButton
            v-if="!isConnected"
            solid
            teal
            sm
            :loading="isConnecting"
            :label="$t('INBOX_MGMT.ADD.EVOLUTION_QR.GET_QRCODE')"
            @click="onConnect"
          />

          <template v-if="isConnected">
            <NextButton
              label="Restart"
              sm
              ghost
              :disabled="isBusy"
              @click="onRestart"
            />
            <NextButton
              solid
              ruby
              sm
              :disabled="isBusy"
              :label="
                $t('INBOX_MGMT.ADD.EVOLUTION.STATES.CLOSE') || 'DISCONNECT'
              "
              @click="onDisconnect"
            />
          </template>
        </div>
      </div>

      <!-- Content Area -->
      <!-- If showing QR Code/Connecting and NOT connected yet -->
      <div
        v-if="!isConnected && showQRPanel"
        class="flex flex-col items-center justify-center min-h-[18rem] rounded-lg border border-n-weak bg-n-solid-1 p-6"
      >
        <div v-if="qrcodeBase64" class="flex flex-col items-center">
          <img
            :key="qrcodeBase64"
            :src="qrcodeBase64"
            alt="Evolution QR Code"
            class="w-64 h-64 object-contain"
          />
          <p v-if="pairingCode" class="mt-3 text-xs opacity-80">
            <strong>{{ pairingCode }}</strong>
          </p>
        </div>
        <div v-else class="text-center opacity-80">
          <woot-spinner />
          <p class="mt-3">
            {{ $t('INBOX_MGMT.CREATE_FLOW.QRCODE.WAITING') }}
          </p>
          <p class="text-xs mt-1">
            {{
              $t('INBOX_MGMT.CREATE_FLOW.QRCODE.WAITING') ||
              'Waiting for QR Code…'
            }}
          </p>
        </div>
      </div>

      <!-- Settings Grid (only if connected) -->
      <div v-else-if="isConnected" class="animate-fade-in-up">
        <!-- Settings Title/Desc inside card if needed, or just the grid -->
        <div class="grid grid-cols-1 gap-4 xs:grid-cols-2">
          <!-- Reject Call -->
          <div
            class="flex flex-col gap-2 p-4 rounded-lg border border-n-weak bg-n-solid-1"
          >
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-n-slate-11">
                {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.REJECT_CALL') }}
              </span>
              <WootSwitch v-model="settings.rejectCall" />
            </div>
            <p class="text-xs text-n-slate-11 mt-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.REJECT_CALL_HELP') }}
            </p>
          </div>

          <!-- Always Online -->
          <div
            class="flex flex-col gap-2 p-4 rounded-lg border border-n-weak bg-n-solid-1"
          >
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-n-slate-11">
                {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.ALWAYS_ONLINE') }}
              </span>
              <WootSwitch v-model="settings.alwaysOnline" />
            </div>
            <p class="text-xs text-n-slate-11 mt-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.ALWAYS_ONLINE_HELP') }}
            </p>
          </div>

          <!-- Read Messages -->
          <div
            class="flex flex-col gap-2 p-4 rounded-lg border border-n-weak bg-n-solid-1"
          >
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-n-slate-11">
                {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.READ_MESSAGES') }}
              </span>
              <WootSwitch v-model="settings.readMessages" />
            </div>
            <p class="text-xs text-n-slate-11 mt-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.READ_MESSAGES_HELP') }}
            </p>
          </div>

          <!-- Read Status -->
          <div
            class="flex flex-col gap-2 p-4 rounded-lg border border-n-weak bg-n-solid-1"
          >
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-n-slate-11">
                {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.READ_STATUS') }}
              </span>
              <WootSwitch v-model="settings.readStatus" />
            </div>
            <p class="text-xs text-n-slate-11 mt-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.READ_STATUS_HELP') }}
            </p>
          </div>

          <!-- Sync Contact Name -->
          <div
            class="flex flex-col gap-2 p-4 rounded-lg border border-n-weak bg-n-solid-1"
          >
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-n-slate-11">
                {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.SYNC_CONTACT_NAME') }}
              </span>
              <WootSwitch v-model="settings.syncContactName" />
            </div>
            <p class="text-xs text-n-slate-11 mt-1">
              {{
                $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.SYNC_CONTACT_NAME_HELP')
              }}
            </p>
          </div>
        </div>

        <!-- Message for Reject Call -->
        <div
          v-if="settings.rejectCall"
          class="mt-4 p-4 rounded-lg border border-n-weak bg-n-solid-1"
        >
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.REJECT_CALL_MESSAGE') }}
          </label>
          <input
            v-model="settings.msgCall"
            type="text"
            class="w-full px-3 py-2 text-sm rounded outline-none border-n-weak bg-n-alpha-1 focus:border-n-brand"
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.EVOLUTION.SETTINGS.REJECT_CALL_MESSAGE_PLACEHOLDER'
              )
            "
          />
        </div>

        <div class="flex justify-end pt-4 mt-4 border-t border-n-weak">
          <NextButton
            :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
            :loading="isUpdating"
            solid
            teal
            @click="updateSettings"
          />
        </div>
      </div>

      <!-- Disconnected Placeholder / Initial State -->
      <div v-else class="pt-8">
        <div
          class="flex justify-center items-center p-8 text-center text-n-slate-11"
        >
          <div>
            <i class="i-lucide-activity mb-2 w-8 h-8 mx-auto" />
            <p class="text-sm">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.HINT_CONNECT_TO_SHOW_QR') }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.min-h-72 {
  min-height: 18rem;
}
.animate-fade-in-up {
  animation: fade-in-up 0.3s ease-out;
}
@keyframes fade-in-up {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
