<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  policy: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);
const store = useStore();
const { t } = useI18n();

const isEditing = computed(() => !!props.policy?.id);

// Form fields
const name = ref('');
const prefix = ref('');
const scope = ref('daily');
const seqPadding = ref(4);
const includeStoreCode = ref(false);
const includeCityCode = ref(false);
const active = ref(true);
const welcomeMessage = ref('');

// Populate form when editing
watch(
  () => props.policy,
  val => {
    if (val) {
      name.value = val.name ?? '';
      prefix.value = val.prefix ?? '';
      scope.value = val.scope ?? 'daily';
      seqPadding.value = val.seq_padding ?? 4;
      includeStoreCode.value = val.include_store_code ?? false;
      includeCityCode.value = val.include_city_code ?? false;
      active.value = val.active ?? true;
      welcomeMessage.value = val.welcome_message ?? '';
    } else {
      name.value = '';
      prefix.value = '';
      scope.value = 'daily';
      seqPadding.value = 4;
      includeStoreCode.value = false;
      includeCityCode.value = false;
      active.value = true;
      welcomeMessage.value = '';
    }
  },
  { immediate: true }
);

const uiFlags = computed(() => store.getters['protocolPolicies/getUIFlags']);
const isLoading = computed(() => uiFlags.value.isCreating || uiFlags.value.isUpdating);

// Preview of generated code
const previewCode = computed(() => {
  const p = prefix.value.toUpperCase() || 'SAC';
  const pad = Number(seqPadding.value) || 4;
  const dateStr = '260307'; // Fixed date for preview consistency
  return {
    prefix: p,
    date: dateStr,
    seq: '1'.padStart(pad, '0'),
    full: `${p}-${dateStr}-${'1'.padStart(pad, '0')}`,
  };
});

const welcomePreview = computed(() =>
  welcomeMessage.value.replace('{{protocol_code}}', previewCode.value.full)
);

const handleSubmit = async () => {
  const payload = {
    protocol_policy: {
      name: name.value,
      prefix: prefix.value,
      scope: scope.value,
      seq_padding: seqPadding.value,
      include_store_code: includeStoreCode.value,
      include_city_code: includeCityCode.value,
      active: active.value,
      welcome_message: welcomeMessage.value || null,
    },
  };

  try {
    if (isEditing.value) {
      await store.dispatch('protocolPolicies/update', {
        id: props.policy.id,
        ...payload,
      });
      useAlert(t('PROTOCOL_POLICIES.FORM.UPDATE.SUCCESS'));
    } else {
      await store.dispatch('protocolPolicies/create', payload);
      useAlert(t('PROTOCOL_POLICIES.FORM.CREATE.SUCCESS'));
    }
    emit('close');
  } catch {
    useAlert(t('PROTOCOL_POLICIES.FORM.ERROR'));
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="isEditing ? $t('PROTOCOL_POLICIES.FORM.EDIT_TITLE') : $t('PROTOCOL_POLICIES.FORM.CREATE_TITLE')"
      :header-content="$t('PROTOCOL_POLICIES.FORM.DESC')"
    />

    <form class="flex flex-col mx-0 px-8 pb-8 gap-4" @submit.prevent="handleSubmit">
      <!-- Preview do código gerado -->
      <div class="flex items-center gap-2 px-3 py-2 rounded-lg border border-n-weak bg-n-slate-2">
        <span class="text-xs font-medium text-n-slate-10">
          {{ $t('PROTOCOL_POLICIES.FORM.PREVIEW') }}
        </span>
        <code class="font-mono text-sm font-bold text-n-brand">
          {{ previewCode.full }}
        </code>
      </div>

      <!-- Nome e Prefixo -->
      <div class="grid grid-cols-2 gap-4">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t('PROTOCOL_POLICIES.FORM.NAME.LABEL') }}
          </span>
          <input
            v-model="name"
            type="text"
            required
            :placeholder="$t('PROTOCOL_POLICIES.FORM.NAME.PLACEHOLDER')"
            class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-brand focus:ring-2 focus:ring-n-brand/10"
          />
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t('PROTOCOL_POLICIES.FORM.PREFIX.LABEL') }}
          </span>
          <input
            v-model="prefix"
            type="text"
            required
            maxlength="10"
            :placeholder="$t('PROTOCOL_POLICIES.FORM.PREFIX.PLACEHOLDER')"
            class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-sm font-mono font-bold uppercase text-n-brand outline-none transition-colors focus:border-n-brand focus:ring-2 focus:ring-n-brand/10"
          />
          <span class="text-xs text-n-slate-9">
            {{ $t('PROTOCOL_POLICIES.FORM.PREFIX.HELP') }}
          </span>
        </label>
      </div>

      <!-- Escopo e Dígitos -->
      <div class="grid grid-cols-2 gap-4">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t('PROTOCOL_POLICIES.FORM.SCOPE.LABEL') }}
          </span>
          <select
            v-model="scope"
            class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-brand focus:ring-2 focus:ring-n-brand/10"
          >
            <option value="daily">{{ $t('PROTOCOL_POLICIES.SCOPE.DAILY') }}</option>
            <option value="global">{{ $t('PROTOCOL_POLICIES.SCOPE.GLOBAL') }}</option>
          </select>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t('PROTOCOL_POLICIES.FORM.PADDING.LABEL') }}
          </span>
          <input
            v-model.number="seqPadding"
            type="number"
            min="2"
            max="8"
            class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-brand focus:ring-2 focus:ring-n-brand/10"
          />
          <span class="text-xs text-n-slate-9">
            {{ $t('PROTOCOL_POLICIES.FORM.PADDING.HELP') }}
          </span>
        </label>
      </div>

      <!-- Mensagem de boas-vindas -->
      <label class="flex flex-col gap-1">
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t('PROTOCOL_POLICIES.FORM.WELCOME_MESSAGE.LABEL') }}
          </span>
          <span class="text-xs text-n-slate-9 border border-n-weak rounded px-1.5 py-0.5">
            {{ $t('PROTOCOL_POLICIES.FORM.WELCOME_MESSAGE.OPTIONAL') }}
          </span>
        </div>
        <span class="text-xs text-n-slate-9">
          {{ $t('PROTOCOL_POLICIES.FORM.WELCOME_MESSAGE.HINT') }}
        </span>
        <textarea
          v-model="welcomeMessage"
          rows="3"
          :placeholder="$t('PROTOCOL_POLICIES.FORM.WELCOME_MESSAGE.PLACEHOLDER')"
          class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-brand focus:ring-2 focus:ring-n-brand/10 resize-none"
        />
        <div
          v-if="welcomeMessage"
          class="mt-1 px-3 py-2 rounded-lg bg-n-slate-2 border border-n-weak text-xs text-n-slate-11"
        >
          <span class="font-medium text-n-slate-12">{{ $t('PROTOCOL_POLICIES.FORM.WELCOME_MESSAGE.PREVIEW') }}</span>
          {{ welcomePreview }}
        </div>
      </label>

      <!-- Opções avançadas -->
      <div class="flex flex-col gap-2 pt-2 border-t border-n-weak">
        <span class="text-sm font-medium text-n-slate-11">
          {{ $t('PROTOCOL_POLICIES.FORM.SECTION_ADVANCED') }}
        </span>

        <label class="flex items-center gap-2 cursor-pointer">
          <input v-model="active" type="checkbox" class="rounded border-n-weak text-n-brand" />
          <span class="text-sm text-n-slate-12">{{ $t('PROTOCOL_POLICIES.FORM.ACTIVE') }}</span>
        </label>

        <label class="flex items-center gap-2 cursor-not-allowed opacity-50">
          <input v-model="includeStoreCode" type="checkbox" disabled class="rounded border-n-weak" />
          <span class="text-sm text-n-slate-11">{{ $t('PROTOCOL_POLICIES.FORM.INCLUDE_STORE_CODE') }}</span>
        </label>

        <label class="flex items-center gap-2 cursor-not-allowed opacity-50">
          <input v-model="includeCityCode" type="checkbox" disabled class="rounded border-n-weak" />
          <span class="text-sm text-n-slate-11">{{ $t('PROTOCOL_POLICIES.FORM.INCLUDE_CITY_CODE') }}</span>
        </label>
      </div>

      <!-- Ações -->
      <div class="flex items-center justify-end gap-2 pt-2">
        <Button
          variant="faded"
          color="slate"
          :label="$t('PROTOCOL_POLICIES.FORM.CANCEL')"
          @click="emit('close')"
        />
        <Button
          type="submit"
          :is-loading="isLoading"
          :label="isEditing ? $t('PROTOCOL_POLICIES.FORM.UPDATE_BTN') : $t('PROTOCOL_POLICIES.FORM.SAVE_BTN')"
        />
      </div>
    </form>
  </div>
</template>

