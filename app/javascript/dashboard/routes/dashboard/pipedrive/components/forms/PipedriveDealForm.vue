<script setup>
import { ref, reactive, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import useVuelidate from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useDebounceFn } from '@vueuse/core';
import PipedriveAPI from 'dashboard/api/pipedrive';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  initialData: { type: Object, default: () => ({}) },
  isLoading: { type: Boolean, default: false },
  actionsClass: { type: String, default: 'justify-start' },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const state = reactive({
  title: props.initialData.title || '',
  value: props.initialData.value || '',
  currency: props.initialData.currency || 'BRL',
  status: props.initialData.status || 'open',
  person_id: props.initialData.person_id || '',
  org_id: props.initialData.org_id || '',
  product_id: '',
  product_price: '',
  product_quantity: 1,
  discount_description: '',
  discount_amount: '',
  discount_type: 'percentage',
  installment_description: '',
  installment_amount: '',
  installment_date: '',
});

const rules = { title: { required } };
const v$ = useVuelidate(rules, state);

const personOptions = ref([]);
const orgOptions = ref([]);
const productOptions = ref([]);

const statusOptions = [
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.OPEN'), value: 'open' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.WON'), value: 'won' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.LOST'), value: 'lost' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.DELETED'), value: 'deleted' },
];

const currencyOptions = [
  { label: 'BRL', value: 'BRL' },
  { label: 'USD', value: 'USD' },
  { label: 'EUR', value: 'EUR' },
  { label: 'GBP', value: 'GBP' },
];

const discountTypeOptions = [
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.DISCOUNT_PERCENTAGE'), value: 'percentage' },
  { label: t('INTEGRATION_SETTINGS.PIPEDRIVE.DISCOUNT_AMOUNT'), value: 'amount' },
];

const fetchProducts = async (search = '') => {
  try {
    const { data } = await PipedriveAPI.getProducts(search);
    productOptions.value = (data.payload || []).map(p => ({
      label: p.name,
      value: p.id,
      price: p.price,
    }));
  } catch (error) {}
};

const fetchPersons = async (search = '') => {
  try {
    const { data } = await PipedriveAPI.getPersons(search);
    personOptions.value = (data.payload || []).map(p => ({ label: p.name, value: p.id }));
  } catch (error) {}
};

const fetchOrganizations = async (search = '') => {
  try {
    const { data } = await PipedriveAPI.getOrganizations(search);
    orgOptions.value = (data.payload || []).map(o => ({ label: o.name, value: o.id }));
  } catch (error) {}
};

const onSearchPerson = useDebounceFn(fetchPersons, 500);
const onSearchOrganization = useDebounceFn(fetchOrganizations, 500);
const onSearchProduct = useDebounceFn(fetchProducts, 500);

const onProductSelect = (id) => {
  const product = productOptions.value.find(p => p.value === id);
  if (product && product.price) {
    state.product_price = product.price;
  }
};

onMounted(() => {
  fetchPersons();
  fetchOrganizations();
  fetchProducts();
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) {
    console.warn('[DealForm] Form validation failed');
    return;
  }
  console.log('[DealForm] Submitting with state:', { ...state });
  emit('submit', { ...state });
};

defineExpose({ submit: handleSubmit });
</script>

<template>
  <form class="flex flex-col gap-6 !pt-0 w-full" @submit.prevent="handleSubmit">
    <!-- Informações Básicas -->
    <div class="flex flex-col gap-4">
      <h3 class="text-sm font-semibold text-n-slate-11">
        {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.BASIC_INFO') }}
      </h3>
      
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <!-- Title -->
        <div class="col-span-1 sm:col-span-2 lg:col-span-3 flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.TITLE') }}
            <span class="text-red-500">*</span>
          </label>
          <Input
            v-model="state.title"
            :placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.PLACEHOLDERS.DEAL_TITLE')"
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
            v-model="state.value"
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

        <!-- Status -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.STATUS') }}
          </label>
          <ComboBox
            v-model="state.status"
            :options="statusOptions"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
          />
        </div>

        <!-- People -->
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
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.ORG_ID') }}
          </label>
          <ComboBox
            v-model="state.org_id"
            :options="orgOptions"
            use-api-results
            :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_ORG')"
            class="bg-n-solid-1 rounded-md [&>div>button]:h-8"
            @search="onSearchOrganization"
          />
        </div>
        
        <div class="hidden lg:block"></div>
      </div>
    </div>

    <!-- Ocionais - Produtos -->
    <div class="flex flex-col gap-4 pt-4 border-t border-n-weak">
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
         <div class="flex flex-col gap-1">
           <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.PRODUCT_OPTIONAL') }}</label>
           <ComboBox v-model="state.product_id" :options="productOptions" use-api-results :search-placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.SEARCH_PRODUCT')" class="bg-n-solid-1 rounded-md [&>div>button]:h-8" @search="onSearchProduct" @update:model-value="onProductSelect" />
         </div>
         <div class="flex flex-col gap-1">
           <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.PRODUCT_PRICE') }}</label>
           <Input v-model="state.product_price" type="number" placeholder="0.00" class="bg-n-solid-1 rounded-md" custom-input-class="h-8 !py-1" />
         </div>
         <div class="flex flex-col gap-1">
           <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.PRODUCT_QUANTITY') }}</label>
           <Input v-model="state.product_quantity" type="number" placeholder="1" class="bg-n-solid-1 rounded-md" custom-input-class="h-8 !py-1" />
         </div>
      </div>
    </div>

    <!-- Descontos -->
    <div class="flex flex-col gap-4 pt-4 border-t border-n-weak">
       <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
           <div class="flex flex-col gap-1">
             <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DISCOUNT_OPTIONAL') }}</label>
             <Input v-model="state.discount_description" :placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.PLACEHOLDERS.COUPON')" class="bg-n-solid-1 rounded-md" custom-input-class="h-8 !py-1" />
           </div>
           <div class="flex flex-col gap-1">
             <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DISCOUNT_VALUE') }}</label>
             <Input v-model="state.discount_amount" type="number" :placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.PLACEHOLDERS.AMOUNT')" class="bg-n-solid-1 rounded-md" custom-input-class="h-8 !py-1" />
           </div>
           <div class="flex flex-col gap-1">
             <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DISCOUNT_TYPE') }}</label>
             <ComboBox v-model="state.discount_type" :options="discountTypeOptions" class="bg-n-solid-1 rounded-md [&>div>button]:h-8" />
           </div>
       </div>
    </div>

    <!-- Parcelamento -->
    <div class="flex flex-col gap-4 pt-4 border-t border-n-weak">
       <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
           <div class="flex flex-col gap-1">
             <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.INSTALLMENT_OPTIONAL') }}</label>
             <Input v-model="state.installment_description" :placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.PLACEHOLDERS.ENTRY')" class="bg-n-solid-1 rounded-md" custom-input-class="h-8 !py-1" />
           </div>
           <div class="flex flex-col gap-1">
             <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.INSTALLMENT_AMOUNT') }}</label>
             <Input v-model="state.installment_amount" type="number" :placeholder="t('INTEGRATION_SETTINGS.PIPEDRIVE.PLACEHOLDERS.AMOUNT')" class="bg-n-solid-1 rounded-md" custom-input-class="h-8 !py-1" />
           </div>
           <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-n-slate-12">{{ t('INTEGRATION_SETTINGS.PIPEDRIVE.INSTALLMENT_DATE') }}</label>
              <Input v-model="state.installment_date" type="date" class="bg-n-solid-1 rounded-md" custom-input-class="h-8 !py-1" />
           </div>
       </div>
    </div>

    <div v-if="$slots.actions" :class="['flex gap-2 mt-4', actionsClass]">
      <slot name="actions" />
    </div>
  </form>
</template>
