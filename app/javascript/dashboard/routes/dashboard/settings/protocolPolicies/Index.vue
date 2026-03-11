<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import PolicyFormModal from './PolicyFormModal.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const { t } = useI18n();

// State
const showFormModal = ref(false);
const selectedPolicy = ref(null);
const showDeleteModal = ref(false);
const policyToDelete = ref(null);
const deleting = ref(false);

// Getters
const records = computed(
  () => store.getters['protocolPolicies/getProtocolPolicies']
);
const uiFlags = computed(() => store.getters['protocolPolicies/getUIFlags']);

onMounted(() => {
  store.dispatch('protocolPolicies/get');
});

const openCreateModal = () => {
  selectedPolicy.value = null;
  showFormModal.value = true;
};

const openEditModal = policy => {
  selectedPolicy.value = { ...policy };
  showFormModal.value = true;
};

const closeFormModal = () => {
  showFormModal.value = false;
  selectedPolicy.value = null;
};

const confirmDelete = policy => {
  policyToDelete.value = policy;
  showDeleteModal.value = true;
};

const closeDeleteModal = () => {
  showDeleteModal.value = false;
  policyToDelete.value = null;
};

const deletePolicy = async () => {
  deleting.value = true;
  try {
    await store.dispatch('protocolPolicies/delete', policyToDelete.value.id);
    useAlert(t('PROTOCOL_POLICIES.DELETE.API.SUCCESS_MESSAGE'));
    closeDeleteModal();
  } catch (e) {
    useAlert(t('PROTOCOL_POLICIES.DELETE.API.ERROR_MESSAGE'));
  } finally {
    deleting.value = false;
  }
};

const scopeLabel = scope =>
  scope === 'global'
    ? t('PROTOCOL_POLICIES.SCOPE.GLOBAL')
    : t('PROTOCOL_POLICIES.SCOPE.DAILY');

const tableHeaders = computed(() => [
  t('PROTOCOL_POLICIES.TABLE.NAME'),
  t('PROTOCOL_POLICIES.TABLE.PREFIX'),
  t('PROTOCOL_POLICIES.TABLE.SCOPE'),
  t('PROTOCOL_POLICIES.TABLE.PADDING'),
  t('PROTOCOL_POLICIES.TABLE.STATUS'),
]);
</script>

<template>
  <div class="relative">
    <!-- Coming Soon Overlay -->
    <div
      class="absolute inset-0 z-50 flex items-center justify-center"
      style="backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px); background: rgba(15, 23, 42, 0.5);"
    >
      <div
        class="flex flex-col items-center gap-4 rounded-3xl border border-white/25 px-16 py-12 text-center"
        style="background: rgba(255,255,255,0.1); box-shadow: 0 25px 50px rgba(0,0,0,0.35); max-width: 440px; width: 90%;"
      >
        <span style="font-size: 3rem; line-height: 1;">🚀</span>
        <h2 class="text-3xl font-extrabold text-white" style="margin: 0; letter-spacing: -0.02em;">Em Breve</h2>
        <p class="text-sm text-white/75" style="line-height: 1.6; margin: 0;">
          Esta funcionalidade está em desenvolvimento<br />e estará disponível em breve.
        </p>
        <span
          class="mt-2 rounded-full px-4 py-1 text-xs font-bold uppercase tracking-widest text-white"
          style="background: rgba(99, 102, 241, 0.85); border: 1px solid rgba(165,180,252,0.4); letter-spacing: 0.1em;"
        >
          Coming Soon
        </span>
      </div>
    </div>

    <SettingsLayout
      :is-loading="uiFlags.isFetching"
      :loading-message="$t('PROTOCOL_POLICIES.LOADING')"
      :no-records-found="!records.length"
      :no-records-message="$t('PROTOCOL_POLICIES.EMPTY_STATE')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('PROTOCOL_POLICIES.HEADER.TITLE')"
        :description="$t('PROTOCOL_POLICIES.HEADER.DESC')"
        feature-name="protocol-policies"
      >
        <template #actions>
          <Button
            icon="i-lucide-circle-plus"
            :label="$t('PROTOCOL_POLICIES.HEADER.NEW_BUTTON')"
            @click="openCreateModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <table class="min-w-full overflow-x-auto divide-y divide-n-weak">
        <thead>
          <th
            v-for="thHeader in tableHeaders"
            :key="thHeader"
            class="py-4 font-semibold text-left ltr:pr-4 rtl:pl-4 text-n-slate-11"
          >
            {{ thHeader }}
          </th>
        </thead>
        <tbody class="flex-1 divide-y divide-n-weak text-n-slate-12">
          <tr v-for="policy in records" :key="policy.id">
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <span class="font-medium text-n-slate-12">
                {{ policy.name }}
              </span>
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <span
                class="font-mono text-sm uppercase px-2 py-0.5 rounded bg-n-slate-3 text-n-slate-11"
              >
                {{ policy.prefix }}
              </span>
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-11">
              {{ scopeLabel(policy.scope) }}
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-11">
              {{ policy.seq_padding }}
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <span
                class="inline-flex items-center gap-1.5 text-xs font-medium"
                :class="policy.active ? 'text-n-teal-11' : 'text-n-slate-9'"
              >
                <span
                  class="size-1.5 rounded-full"
                  :class="policy.active ? 'bg-n-teal-11' : 'bg-n-slate-7'"
                />
                {{
                  policy.active
                    ? $t('PROTOCOL_POLICIES.STATUS.ACTIVE')
                    : $t('PROTOCOL_POLICIES.STATUS.INACTIVE')
                }}
              </span>
            </td>
            <td class="py-4 min-w-xs">
              <div class="flex gap-1 justify-end">
                <Button
                  v-tooltip.top="$t('PROTOCOL_POLICIES.TABLE.EDIT')"
                  icon="i-lucide-pen"
                  slate
                  xs
                  faded
                  @click="openEditModal(policy)"
                />
                <Button
                  v-tooltip.top="$t('PROTOCOL_POLICIES.TABLE.DELETE')"
                  icon="i-lucide-trash-2"
                  xs
                  ruby
                  faded
                  @click="confirmDelete(policy)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <woot-modal v-model:show="showFormModal" :on-close="closeFormModal">
      <PolicyFormModal :policy="selectedPolicy" @close="closeFormModal" />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteModal"
      :on-confirm="deletePolicy"
      :on-close="closeDeleteModal"
      :title="$t('PROTOCOL_POLICIES.DELETE.CONFIRM.TITLE')"
      :message="$t('PROTOCOL_POLICIES.DELETE.CONFIRM.MESSAGE')"
      :message-value="policyToDelete ? policyToDelete.name : ''"
      :confirm-text="$t('PROTOCOL_POLICIES.DELETE.CONFIRM.YES')"
      :reject-text="$t('PROTOCOL_POLICIES.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
  </div>
</template>

