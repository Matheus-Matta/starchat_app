<script setup>
import { ref, reactive, onMounted, computed } from 'vue';
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

const isEditMode = computed(() => !!props.initialData.id);

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const state = reactive({
  subject: props.initialData.subject || '',
  type: props.initialData.type || 'call',
  owner_id: props.initialData.owner_id || props.initialData.user_id || '',
  deal_id: props.initialData.deal_id || '',
  lead_id: props.initialData.lead_id || '',
  person_id: props.initialData.person_id || '',
  org_id: props.initialData.org_id || '',
  due_date: props.initialData.due_date || '',
  due_time: props.initialData.due_time || '',
  duration: props.initialData.duration || '',
  priority: props.initialData.priority || 0,
  busy: props.initialData.busy || false,
  done: props.initialData.done || false,
  public_description: props.initialData.public_description || '',
  note: props.initialData.note || '',
});

const rules = { subject: { required } };
const v$ = useVuelidate(rules, state);

const typeOptions = [
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.CALL'), value: 'call' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.MEETING'), value: 'meeting' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.TASK'), value: 'task' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.DEADLINE'), value: 'deadline' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.EMAIL'), value: 'email' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.LUNCH'), value: 'lunch' },
];

const priorityOptions = [
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.PRIORITY_OPTIONS.NORMAL'), value: 0 },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.PRIORITY_OPTIONS.HIGH'), value: 1 },
];

const userOptions = ref([]);
const dealOptions = ref([]);
const leadOptions = ref([]);
const personOptions = ref([]);
const orgOptions = ref([]);

const fetchUsers = async (term = '') => {
  try {
    const { data } = await PipedriveAPI.getUsers(term);
    const options = (data.payload || []).map(u => ({ label: u.name, value: u.id }));
    const currentOwnerId = state.owner_id;
    const initialOwnerId = props.initialData.owner_id || props.initialData.user_id;
    if (currentOwnerId && initialOwnerId === currentOwnerId && props.initialData.owner_name) {
      if (!options.find(o => o.value === currentOwnerId)) {
        options.unshift({ label: props.initialData.owner_name, value: currentOwnerId });
      }
    }
    userOptions.value = options;
  } catch (e) {}
};

const fetchDeals = async (term = '') => {
  try {
    const { data } = await PipedriveAPI.getDeals({ search: term, limit: 5 });
    const options = (data.payload || []).map(d => ({ label: d.title, value: d.id }));
    if (state.deal_id && props.initialData.deal_id === state.deal_id && props.initialData.deal_title) {
       if (!options.find(o => o.value === state.deal_id)) {
         options.unshift({ label: props.initialData.deal_title, value: props.initialData.deal_id });
       }
    }
    dealOptions.value = options;
  } catch (e) {}
};

const fetchLeads = async (term = '') => {
  try {
    const { data } = await PipedriveAPI.getLeads({ search: term, limit: 5 });
    const options = (data.payload || []).map(l => ({ label: l.title, value: l.id }));
    if (state.lead_id && props.initialData.lead_id === state.lead_id && props.initialData.lead_title) {
       if (!options.find(o => o.value === state.lead_id)) {
         options.unshift({ label: props.initialData.lead_title, value: props.initialData.lead_id });
       }
    }
    leadOptions.value = options;
  } catch (e) {}
};

const fetchPersons = async (term = '') => {
  try {
    const { data } = await PipedriveAPI.getPersons(term);
    const options = (data.payload || []).map(p => ({ label: p.name, value: p.id }));
    if (state.person_id && props.initialData.person_id === state.person_id && props.initialData.person_name) {
       if (!options.find(o => o.value === state.person_id)) {
         options.unshift({ label: props.initialData.person_name, value: props.initialData.person_id });
       }
    }
    personOptions.value = options;
  } catch (e) {}
};

const fetchOrgs = async (term = '') => {
  try {
    const { data } = await PipedriveAPI.getOrganizations(term);
    const options = (data.payload || []).map(o => ({ label: o.name, value: o.id }));
    if (state.org_id && props.initialData.org_id === state.org_id && props.initialData.org_name) {
       if (!options.find(o => o.value === state.org_id)) {
         options.unshift({ label: props.initialData.org_name, value: props.initialData.org_id });
       }
    }
    orgOptions.value = options;
  } catch (e) {}
};

const onSearchUser = useDebounceFn(fetchUsers, 500);
const onSearchDeal = useDebounceFn(fetchDeals, 500);
const onSearchLead = useDebounceFn(fetchLeads, 500);
const onSearchPerson = useDebounceFn(fetchPersons, 500);
const onSearchOrg = useDebounceFn(fetchOrgs, 500);

onMounted(() => {
  fetchUsers();
  fetchDeals();
  fetchLeads();
  fetchPersons();
  fetchOrgs();
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) {
    console.warn('[ActivityForm] Form validation failed');
    return;
  }
  console.log('[ActivityForm] Submitting with state:', { ...state });
  emit('submit', { ...state });
};

defineExpose({ submit: handleSubmit });
</script>

<template>
  <form class="flex flex-col gap-6 !pt-0 w-full" @submit.prevent="handleSubmit">
    <div class="flex flex-col gap-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <!-- Subject -->
        <div class="col-span-1 sm:col-span-2 lg:col-span-3 flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.SUBJECT') }}
            <span class="text-red-500">*</span>
          </label>
          <Input
            v-model="state.subject"
            :placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.PLACEHOLDERS.ACTIVITY_SUBJECT')"
            :message-type="v$.subject.$error ? 'error' : undefined"
            class="bg-n-solid-1 rounded-md"
            custom-input-class="h-8 !py-1"
            @blur="v$.subject.$touch()"
          />
        </div>

        <!-- Type -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.TYPE') }}
          </label>
          <ComboBox
            v-model="state.type"
            :options="typeOptions"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
          />
        </div>

        <!-- Priority -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.PRIORITY') }}
          </label>
          <ComboBox
            v-model="state.priority"
            :options="priorityOptions"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
          />
        </div>

        <!-- Date -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DATE') }}
          </label>
          <Input
            v-model="state.due_date"
            type="date"
            class="bg-n-solid-1 rounded-md"
            custom-input-class="h-8 !py-1"
          />
        </div>

        <!-- Time -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.TIME') }}
          </label>
          <Input
            v-model="state.due_time"
            type="time"
            class="bg-n-solid-1 rounded-md"
            custom-input-class="h-8 !py-1"
          />
        </div>

        <!-- Duration -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DURATION') }}
          </label>
          <Input
            v-model="state.duration"
            :placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.PLACEHOLDERS.DURATION')"
            class="bg-n-solid-1 rounded-md"
            custom-input-class="h-8 !py-1"
          />
        </div>
        
        <div class="hidden lg:block"></div>
      </div>

      <!-- Relationships -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 pt-4 border-t border-n-weak">
        <!-- Owners -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.OWNER') }}</label>
          <ComboBox
            v-model="state.owner_id"
            :options="userOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_OWNER')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            @search="onSearchUser"
          />
        </div>

        <!-- Person -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.PERSON_ID') }}</label>
          <ComboBox
            v-model="state.person_id"
            :options="personOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_PERSON')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            :disabled="isEditMode"
            @search="onSearchPerson"
          />
        </div>

        <!-- Org -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.ORG_ID') }}</label>
          <ComboBox
            v-model="state.org_id"
            :options="orgOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_ORG')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            :disabled="isEditMode"
            @search="onSearchOrg"
          />
        </div>

        <!-- Deal -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.MODAL.TABLE.DEAL') }}</label>
          <ComboBox
            v-model="state.deal_id"
            :options="dealOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_DEAL')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            @search="onSearchDeal"
          />
        </div>

        <!-- Lead -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.LEADS') }}</label>
          <ComboBox
            v-model="state.lead_id"
            :options="leadOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_LEAD')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            @search="onSearchLead"
          />
        </div>

        <!-- Done -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DONE_QUESTION') }}</label>
          <div class="flex items-center justify-between h-8">
            <span class="text-sm text-n-slate-11">
              {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.MARK_AS_DONE') }}
            </span>
            <Switch v-model="state.done" />
          </div>
        </div>
        
        <!-- Busy -->
        <div class="flex items-center gap-2 h-8 pt-4">
          <Switch v-model="state.busy" />
          <span class="text-sm font-medium text-n-slate-12 cursor-pointer" @click="state.busy = !state.busy">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.BUSY') }}
          </span>
        </div>
      </div>

      <!-- Note & Public Description -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-4 border-t border-n-weak">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.NOTE') }}
          </label>
          <textarea
            v-model="state.note"
            class="w-full text-sm bg-n-solid-1 border rounded-md outline-none text-n-slate-12 border-n-weak focus:border-n-brand h-24 p-2"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.PUBLIC_DESCRIPTION') }}
          </label>
          <textarea
            v-model="state.public_description"
            class="w-full text-sm bg-n-solid-1 border rounded-md outline-none text-n-slate-12 border-n-weak focus:border-n-brand h-24 p-2"
          />
        </div>
      </div>
    </div>

    <div v-if="$slots.actions" :class="['flex gap-2 mt-4', actionsClass]">
      <slot name="actions" />
    </div>
  </form>
</template>
