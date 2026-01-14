<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Integration from './Integration.vue';
import Spinner from 'shared/components/Spinner.vue';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';

const store = useStore();
const { t } = useI18n();

const integrationLoaded = ref(false);

const showConnectModal = ref(false);
const apiToken = ref('');
const companyDomain = ref('');
const syncContacts = ref(false);
const importContacts = ref(false);
const isConnecting = ref(false);
const isUpdating = ref(false);

// Granular Sync Flags
const syncName = ref(false);
const syncEmail = ref(false);
const syncPhone = ref(false);
const syncOrg = ref(false);

const integration = computed(() => {
  return store.getters['integrations/getIntegration']('pipedrive');
});

const uiFlags = computed(() => store.getters['integrations/getUIFlags']);

const integrationAction = computed(() => {
  return integration.value.enabled ? 'disconnect' : integration.value.action;
});

const initializePipedriveIntegration = async () => {
  await store.dispatch('integrations/get', 'pipedrive');
  integrationLoaded.value = true;

  if (integration.value.enabled) {
    const s = integration.value.settings || {};
    apiToken.value = s.api_token;
    companyDomain.value = s.company_domain;
    syncContacts.value = s.sync_contacts;
    importContacts.value = s.import_contacts !== false;

    syncName.value = s.sync_name !== false;
    syncEmail.value = s.sync_email !== false;
    syncPhone.value = s.sync_phone !== false;
    syncOrg.value = s.sync_organization !== false;
  }
};

const openConnectModal = () => {
  showConnectModal.value = true;
};

const closeConnectModal = () => {
  showConnectModal.value = false;
};

const connectAccount = async () => {
  isConnecting.value = true;
  try {
    const payload = {
      app_id: 'pipedrive',
      settings: {
        api_token: apiToken.value,
        company_domain: companyDomain.value,
        sync_contacts: syncContacts.value,
        import_contacts: importContacts.value,
        sync_name: syncName.value,
        sync_email: syncEmail.value,
        sync_phone: syncPhone.value,
        sync_organization: syncOrg.value,
      },
    };

    await store.dispatch('integrations/createHook', payload);
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_SUCCESS'));
    closeConnectModal();
    // Refresh integrations to update UI
    await store.dispatch('integrations/get', 'pipedrive');
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_ERROR'));
  } finally {
    isConnecting.value = false;
  }
};

const updateSettings = async () => {
  isUpdating.value = true;
  try {
    const payload = {
      app_id: 'pipedrive',
      settings: {
        api_token: apiToken.value,
        company_domain: companyDomain.value,
        sync_contacts: syncContacts.value,
        import_contacts: importContacts.value,
        sync_name: syncName.value,
        sync_email: syncEmail.value,
        sync_phone: syncPhone.value,
        sync_organization: syncOrg.value,
      },
    };

    await store.dispatch('integrations/createHook', payload);
    useAlert(t('general.success'));
  } catch (error) {
    useAlert(t('general.error'));
  } finally {
    isUpdating.value = false;
  }
};

onMounted(() => {
  initializePipedriveIntegration();
});
</script>

<template>
  <div class="flex-grow flex-shrink p-4 overflow-auto">
    <div v-if="integrationLoaded && !uiFlags.isCreatingPipedrive">
      <Integration
        :integration-id="integration.id"
        :integration-logo="integration.logo"
        :integration-name="integration.name"
        :integration-description="integration.description"
        :integration-enabled="integration.enabled"
        :integration-action="integrationAction"
        :action-button-text="$t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE')"
        :delete-confirmation-text="{
          title: $t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE_CONFIRMATION.TITLE'),
          message: $t(
            'INTEGRATION_SETTINGS.PIPEDRIVE.DELETE_CONFIRMATION.MESSAGE'
          ),
        }"
      >
        <template #action>
          <Button
            v-if="!integration.enabled"
            :label="$t('INTEGRATION_SETTINGS.CONNECT.BUTTON_TEXT')"
            faded
            blue
            @click="openConnectModal"
          />
        </template>

        <!-- Configuration UI for Connected State -->
        <div
          v-if="integration.enabled"
          class="mt-6 border-t border-n-weak pt-6"
        >
          <h3 class="text-base font-medium text-n-slate-12 mb-4">
            {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.TITLE') }}
          </h3>

          <div class="flex flex-col gap-4 max-w-lg">
            <!-- Global Sync Switch -->
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  $t(
                    'INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.SYNC_CONTACTS'
                  )
                }}
              </span>
              <Switch v-model="syncContacts" />
            </div>

            <!-- Import Toggle (New) -->
            <div
              class="flex items-center justify-between pl-4 border-l-2 border-n-weak ml-1 mt-4 transition-opacity duration-200"
              :class="{ 'opacity-50 pointer-events-none': !syncContacts }"
            >
              <span class="text-sm text-n-slate-11">
                {{
                  $t(
                    'INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.IMPORT_CONTACTS_TOGGLE'
                  )
                }}
              </span>
              <Switch v-model="importContacts" :disabled="!syncContacts" />
            </div>

            <!-- Import Action (Visible only when Sync is ON AND Import Permission is ON) -->
            <div
              v-if="syncContacts && importContacts"
              class="flex justify-end pr-1 mb-2"
            >
              <Button
                :label="
                  $t(
                    'INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.IMPORT_CONTACTS'
                  ) || 'Importar Contatos'
                "
                size="small"
                variant="outline"
                icon="arrow-download"
                :is-loading="isUpdating"
                @click="updateSettings"
              />
            </div>

            <!-- Granular Switches (Dependent) -->
            <div
              class="flex flex-col gap-4 pl-4 border-l-2 border-n-weak ml-1 transition-opacity duration-200"
              :class="{ 'opacity-50 pointer-events-none': !syncContacts }"
            >
              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-11">
                  {{
                    $t(
                      'INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.SYNC_PHONE'
                    )
                  }}
                </span>
                <Switch v-model="syncPhone" :disabled="!syncContacts" />
              </div>

              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-11">
                  {{
                    $t(
                      'INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.SYNC_EMAIL'
                    )
                  }}
                </span>
                <Switch v-model="syncEmail" :disabled="!syncContacts" />
              </div>

              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-11">
                  {{
                    $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.SYNC_NAME')
                  }}
                </span>
                <Switch v-model="syncName" :disabled="!syncContacts" />
              </div>

              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-11">
                  {{
                    $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.SYNC_ORG')
                  }}
                </span>
                <Switch v-model="syncOrg" :disabled="!syncContacts" />
              </div>
            </div>

            <div class="flex gap-2 mt-4 items-center">
              <Button
                :label="$t('general.update')"
                :is-loading="isUpdating"
                @click="updateSettings"
              />
            </div>
          </div>
        </div>
      </Integration>
    </div>
    <div v-else class="flex items-center justify-center flex-1">
      <Spinner size="" color-scheme="primary" />
    </div>

    <!-- Connect Modal -->
    <Modal
      :show="showConnectModal"
      :title="$t('INTEGRATION_SETTINGS.CONNECT.BUTTON_TEXT')"
      @close="closeConnectModal"
    >
      <div class="w-full flex flex-col gap-4 px-8 py-8">
        <div class="flex flex-col gap-1">
          <h2 class="text-xl font-medium text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.DESCRIPTION') }}
          </p>
        </div>

        <div class="flex flex-col gap-4 mt-2">
          <!-- API Token -->
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.API_TOKEN') }}
            </label>
            <Input
              v-model="apiToken"
              type="text"
              :placeholder="
                $t(
                  'INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.API_TOKEN_PLACEHOLDER'
                )
              "
            />
          </div>

          <!-- Company Domain -->
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{
                $t(
                  'INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.COMPANY_DOMAIN'
                )
              }}
            </label>
            <div class="relative">
              <Input
                v-model="companyDomain"
                type="text"
                :placeholder="
                  $t(
                    'INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.COMPANY_DOMAIN_PLACEHOLDER'
                  )
                "
              />
              <span
                class="text-xs text-n-slate-11 mt-1 block"
                v-html="
                  $t(
                    'INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.COMPANY_DOMAIN_HINT'
                  )
                "
              />
            </div>
          </div>

          <!-- Sync Preferences -->
          <div class="flex flex-col gap-2 rounded-md">
            <span class="text-xs font-semibold text-n-slate-11 uppercase mb-1">
              {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.TITLE') }}
            </span>
            <div class="flex items-center justify-between">
              <span class="text-sm text-n-slate-12">
                {{
                  $t(
                    'INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.SYNC_CONTACTS'
                  )
                }}
              </span>
              <Switch v-model="syncContacts" small />
            </div>

            <div
              class="flex flex-col gap-2 pl-2 border-l-2 border-n-weak ml-1 mt-1 transition-opacity duration-200"
              :class="{ 'opacity-50 pointer-events-none': !syncContacts }"
            >
              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-12">
                  {{
                    $t(
                      'INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.IMPORT_CONTACTS_TOGGLE'
                    )
                  }}
                </span>
                <Switch
                  v-model="importContacts"
                  small
                  :disabled="!syncContacts"
                />
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-12">
                  {{
                    $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.SYNC_NAME')
                  }}
                </span>
                <Switch v-model="syncName" small :disabled="!syncContacts" />
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-12">
                  {{
                    $t(
                      'INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.SYNC_PHONE'
                    )
                  }}
                </span>
                <Switch v-model="syncPhone" small :disabled="!syncContacts" />
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-12">
                  {{
                    $t(
                      'INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.SYNC_EMAIL'
                    )
                  }}
                </span>
                <Switch v-model="syncEmail" small :disabled="!syncContacts" />
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm text-n-slate-12">
                  {{
                    $t('INTEGRATION_SETTINGS.PIPEDRIVE.CONFIGURATION.SYNC_ORG')
                  }}
                </span>
                <Switch v-model="syncOrg" small :disabled="!syncContacts" />
              </div>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-2 mt-6">
          <Button
            :label="$t('INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.CANCEL')"
            variant="ghost"
            @click="closeConnectModal"
          />
          <Button
            :label="$t('INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.CONNECT')"
            :is-loading="isConnecting"
            :disabled="!apiToken || !companyDomain || isConnecting"
            @click="connectAccount"
          />
        </div>
      </div>
    </Modal>
  </div>
</template>
