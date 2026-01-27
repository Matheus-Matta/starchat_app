<script setup>
import { ref, reactive, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import useVuelidate from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useDebounceFn } from '@vueuse/core';
import PipedriveAPI from 'dashboard/api/pipedrive';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  initialData: { type: Object, default: () => ({}) },
  isLoading: { type: Boolean, default: false },
  actionsClass: { type: String, default: 'justify-start' },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const state = reactive({
  title: props.initialData.title || '',
  amount: props.initialData.value?.amount || props.initialData.amount || '',
  currency: props.initialData.value?.currency || props.initialData.currency || 'BRL',
  person_id: props.initialData.person_id || '',
  organization_id: props.initialData.organization_id || props.initialData.organization?.id || '',
  owner_id: props.initialData.owner_id || props.initialData.user?.id || '',
  label_ids: props.initialData.label_ids || [],
  expected_close_date: props.initialData.expected_close_date || '',
  visible_to: props.initialData.visible_to || '3',
  was_seen: props.initialData.was_seen || false,
});

const rules = { title: { required } };
const v$ = useVuelidate(rules, state);

const personOptions = ref([]);
const organizationOptions = ref([]);
const userOptions = ref([]);
const labelOptions = ref([]);

const visibleToOptions = [
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.VISIBLE_TO_OPTIONS.OWNER_AND_FOLLOWERS'), value: '1' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.VISIBLE_TO_OPTIONS.ENTIRE_COMPANY'), value: '3' },
];

const currencyOptions = [
  { label: 'BRL', value: 'BRL' },
  { label: 'USD', value: 'USD' },
  { label: 'EUR', value: 'EUR' },
  { label: 'GBP', value: 'GBP' },
];

const fetchPersons = async (search = '') => {
  try {
    const { data } = await PipedriveAPI.getPersons(search);
    personOptions.value = (data.payload || []).map(p => ({ label: p.name, value: p.id }));
  } catch (error) {}
};

const fetchOrganizations = async (search = '') => {
  try {
    const { data } = await PipedriveAPI.getOrganizations(search);
    organizationOptions.value = (data.payload || []).map(o => ({ label: o.name, value: o.id }));
  } catch (error) {}
};

const fetchUsers = async (search = '') => {
  try {
    const { data } = await PipedriveAPI.getUsers(search);
    userOptions.value = (data.payload || []).map(u => ({ label: u.name, value: u.id }));
  } catch (error) {}
};

const fetchLabels = async () => {
  try {
    const { data } = await PipedriveAPI.getLeadLabels();
    labelOptions.value = (data.payload || []).map(l => ({ label: l.name, value: l.id }));
  } catch (error) {}
};

const onSearchPerson = useDebounceFn(fetchPersons, 500);
const onSearchOrganization = useDebounceFn(fetchOrganizations, 500);
const onSearchUser = useDebounceFn(fetchUsers, 500);

onMounted(() => {
  fetchPersons();
  fetchOrganizations();
  fetchUsers();
  fetchLabels();
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) {
    console.warn('[LeadForm] Form validation failed');
    return;
  }
  console.log('[LeadForm] Submitting with state:', { ...state });
  emit('submit', { ...state });
};

defineExpose({ submit: handleSubmit });
</script>

<template>
  <form class="flex flex-col gap-6 !pt-0 w-full" @submit.prevent="handleSubmit">
    <div class="flex flex-col gap-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <!-- Title -->
        <div class="col-span-1 sm:col-span-2 lg:col-span-3 flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.TITLE') }}
            <span class="text-red-500">*</span>
          </label>
          <Input
            v-model="state.title"
            :placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.PLACEHOLDERS.LEAD_TITLE')"
            :message-type="v$.title.$error ? 'error' : undefined"
            class="bg-n-solid-1 rounded-md"
            custom-input-class="h-8 !py-1"
            @blur="v$.title.$touch()"
          />
        </div>

        <!-- Value & Currency -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.VALUE') }}
          </label>
          <Input
            v-model="state.amount"
            type="number"
            placeholder="0.00"
            class="bg-n-solid-1 rounded-md"
            custom-input-class="h-8 !py-1"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.CURRENCY') }}
          </label>
          <ComboBox
            v-model="state.currency"
            :options="currencyOptions"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
          />
        </div>

        <!-- Expected Close Date -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.EXPECTED_CLOSE_DATE') }}
          </label>
          <Input
            v-model="state.expected_close_date"
            type="date"
            class="bg-n-solid-1 rounded-md"
            custom-input-class="h-8 !py-1"
          />
        </div>

        <div class="hidden lg:block"></div>

        <!-- Relationships Header -->
        <div class="col-span-1 sm:col-span-2 lg:col-span-3 pt-2">
          <h3 class="text-sm font-semibold text-n-slate-11">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DETAILS_RELATIONS') }}
          </h3>
        </div>

        <!-- Owner -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.OWNER') }}
          </label>
          <ComboBox
            v-model="state.owner_id"
            :options="userOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_OWNER')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            @search="onSearchUser"
          />
        </div>

        <!-- Label -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.LABEL') }}
          </label>
          <ComboBox
            :model-value="state.label_ids[0]"
            @update:model-value="(val) => state.label_ids = val ? [val] : []"
            :options="labelOptions"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
          />
        </div>

        <!-- Visible To -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.VISIBLE_TO') }}
          </label>
          <ComboBox
            v-model="state.visible_to"
            :options="visibleToOptions"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
          />
        </div>

        <!-- Person -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.PERSON_ID') }}
          </label>
          <ComboBox
            v-model="state.person_id"
            :options="personOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_PERSON')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            @search="onSearchPerson"
          />
        </div>

        <!-- Organization -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.ORG_ID') }}
          </label>
          <ComboBox
            v-model="state.organization_id"
            :options="organizationOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_ORG')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            @search="onSearchOrganization"
          />
        </div>

        <!-- Was Seen -->
        <div class="flex flex-col gap-1 justify-end pb-1">
          <div class="flex items-center gap-2 h-8">
            <Switch v-model="state.was_seen" />
            <span class="text-sm font-medium text-n-slate-12 cursor-pointer" @click="state.was_seen = !state.was_seen">
              {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.WAS_SEEN') }}
            </span>
          </div>
        </div>
      </div>
      <p class="text-xs text-n-slate-9 tracking-tight">
        {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.LEAD_REQ_HELP') }}
      </p>
    </div>
    <div v-if="$slots.actions" :class="['flex gap-2 mt-4', actionsClass]">
      <slot name="actions" />
    </div>
  </form>
</template>
