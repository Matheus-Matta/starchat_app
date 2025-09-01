<script>
import { emitter } from 'shared/helpers/mitt';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  name: 'EvolutionControls',
  components: { NextButton },
  props: {
    inbox: { type: Object, default: () => ({}) },
  },
  data() {
    return {
      // UI/estado
      state: 'disconnected',
      qrcodeBase64: '',
      pairingCode: '',
      isSubscribed: true,
      isBusy: false,
      waitingQR: false,
      showQRPanel: false,

      // channel completo
      channel: null,
      channelLoading: false,
      channelError: '',
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
      return this.$t(`INBOX_MGMT.ADD.EVOLUTION.STATES.${this.stateBadge.i18n}`);
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

    this._onReconnect = () => {
      this.isSubscribed = true;
    };
    this._onDisconnect = () => {
      this.isSubscribed = false;
    };
    emitter.on('WEBSOCKET_RECONNECT', this._onReconnect);
    emitter.on('WEBSOCKET_DISCONNECT', this._onDisconnect);

    this._onQR = p => {
      if (Number(p.inbox_id) !== Number(this.inbox?.id)) return;
      const b64 = String(p.qrcode_base64 || '').trim();
      if (b64) {
        this.qrcodeBase64 = b64;
        this.waitingQR = false;
      }
      this.pairingCode = p.pairing_code || '';
    };

    this._onConn = p => {
      if (Number(p.inbox_id) !== Number(this.inbox?.id)) return;
      if (p.state) this.state = p.state;
      if (this.isConnected) {
        this.waitingQR = false;
        this.qrcodeBase64 = '';
        this.pairingCode = '';
      }
    };

    emitter.on('evolution:qrcode_updated', this._onQR);
    emitter.on('evolution:connection_update', this._onConn);
    console.log(this.inbox, this.channel);
  },
  beforeUnmount() {
    emitter.off('WEBSOCKET_RECONNECT', this._onReconnect);
    emitter.off('WEBSOCKET_DISCONNECT', this._onDisconnect);
    emitter.off('evolution:qrcode_updated', this._onQR);
    emitter.off('evolution:connection_update', this._onConn);
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
      } catch (e) {
        console.error('[EvolutionControls] fetchChannel erro:', e);
        this.channelError =
          e?.message || 'Não foi possível carregar o canal (Evolution).';
      } finally {
        this.channelLoading = false;
      }
    },
    async onConnect() {
      console.log(this.channel);
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
        console.error('[EvolutionControls] connect erro:', e);
        this.state = 'error';
        this.waitingQR = false;
      } finally {
        this.isBusy = false;
      }
    },

    async onDisconnect() {
      console.log(this.channel);
      if (!this.channel?.id) return;

      this.isBusy = true;
      try {
        await this.$store.dispatch('evolution/disconnect', {
          id: this.channel.id,
        });
        // resposta é 204; estado real chega via WS. Reflete localmente:
        this.state = 'disconnected';
        this.showQRPanel = false;
        this.waitingQR = false;
        this.qrcodeBase64 = '';
        this.pairingCode = '';
      } catch (e) {
        console.error('[EvolutionControls] disconnect erro:', e);
      } finally {
        this.isBusy = false;
      }
    },

    async onRestart() {
      console.log(this.channel);
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
        console.error('[EvolutionControls] restart erro:', e);
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
  <div class="mx-8">
    <!-- Cabeçalho -->
    <div class="ml-0 mr-0 py-8 w-full">
      <div class="grid grid-cols-1 lg:grid-cols-8 gap-6">
        <div class="col-span-2">
          <p class="text-base text-n-brand mb-0 font-medium">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.TITLE') }}
          </p>
          <p
            class="text-sm mb-2 text-n-slate-11 leading-5 tracking-normal mt-2"
          >
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.QR.INSTRUCTION') }}
          </p>
        </div>

        <!-- Card principal -->
        <div class="col-span-6 xl:col-span-5">
          <!-- Linha de status + botões -->
          <div class="flex items-center justify-between mb-4">
            <!-- Badge de estado -->
            <span
              class="flex flex-row items-center py-0.5 px-2 rounded text-xs"
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

            <!-- Botões de ação -->
            <div class="flex items-center gap-2">
              <NextButton
                v-if="!isConnected"
                solid
                teal
                :loading="isConnecting"
                :label="$t('INBOX_MGMT.ADD.EVOLUTION_QR.GET_QRCODE')"
                @click="onConnect"
              />
            </div>
          </div>

          <!-- Conteúdo do card -->
          <div class="border border-n-weak rounded-lg bg-n-solid-1 p-6 w-full">
            <div class="flex flex-col items-center justify-center min-h-72">
              <template v-if="isConnected">
                <div class="flex flex-col items-center gap-3">
                  <i class="i-lucide-check-circle text-3xl text-emerald-600" />
                  <p class="text-sm opacity-80">
                    {{
                      $t('INBOX_MGMT.ADD.EVOLUTION.STATES.CONNECTED') ||
                      'Instance is connected.'
                    }}
                  </p>
                  <NextButton
                    solid
                    ruby
                    :disabled="isBusy"
                    :label="
                      $t('INBOX_MGMT.ADD.EVOLUTION.STATES.CLOSE') ||
                      'DISCONNECT'
                    "
                    @click="onDisconnect"
                  />
                </div>
              </template>

              <!-- Não conectado -->
              <template v-else>
                <!-- Painel de QR só quando o usuário clicou em Conectar -->
                <template v-if="showQRPanel && !isConnected">
                  <!-- QR pronto -->
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

                  <!-- Aguardando QR -->
                  <div v-else class="text-center opacity-80">
                    <woot-loading-indicator
                      v-if="
                        waitingQR ||
                        ['connecting', 'qrcode', 'pairing'].includes(
                          String(state).toLowerCase()
                        )
                      "
                    />
                    <p class="mt-3">
                      {{
                        $t('INBOX_MGMT.ADD.EVOLUTION.QR.PANEL_TITLE') ||
                        'QR Code'
                      }}
                    </p>
                    <p class="text-xs mt-1">
                      {{
                        $t('INBOX_MGMT.CREATE_FLOW.QRCODE.WAITING') ||
                        'Waiting for QR Code…'
                      }}
                    </p>
                  </div>
                </template>

                <!-- Aguardando ação do usuário -->
                <template v-else>
                  <div class="text-center opacity-80">
                    <p class="text-sm">
                      {{
                        $t('INBOX_MGMT.ADD.EVOLUTION.HINT_CONNECT_TO_SHOW_QR')
                      }}
                    </p>
                  </div>
                </template>
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Ações secundárias (Restart) -->
    <div class="ml-0 mr-0 py-8 w-full">
      <div class="grid grid-cols-1 lg:grid-cols-8 gap-6">
        <div class="col-span-2" />
        <div class="col-span-6 xl:col-span-5 flex items-center gap-3">
          <NextButton
            solid
            blue
            :disabled="isBusy"
            :label="$t('INBOX_MGMT.ADD.EVOLUTION.STATES.RESTART')"
            @click="onRestart"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.min-h-72 {
  min-height: 18rem;
}
</style>
