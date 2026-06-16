<script setup>
import { h, ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import TextArea from 'next/textarea/TextArea.vue';
import Switch from 'next/switch/Switch.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DurationInput from 'next/input/DurationInput.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';

const props = defineProps({
  initialData: { type: Object, default: () => ({}) },
  mode: {
    type: String,
    default: 'CREATE',
    validator: v => ['CREATE', 'EDIT'].includes(v),
  },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const labels = useMapGetter('labels/getLabels');

const name = ref('');
const enabled = ref(true);

const reengagementMessage = ref('');
const reengagementInterval = ref(null);
const reengagementUnit = ref(DURATION_UNITS.MINUTES);

const autoResolveDuration = ref(null);
const autoResolveUnit = ref(DURATION_UNITS.MINUTES);
const autoResolveMessage = ref('');
const autoResolveIgnoreWaiting = ref(false);
const noClientLabel = ref(null);
const noAgentLabel = ref(null);

const labelOptions = computed(() =>
  labels.value?.length
    ? labels.value.map(label => ({
        id: label.title,
        name: label.title,
        icon: h('span', {
          class: 'size-[12px] ring-1 ring-n-alpha-1 dark:ring-white/20 ring-inset rounded-sm',
          style: { backgroundColor: label.color },
        }),
      }))
    : []
);

const unitFromMinutes = minutes => {
  if (!minutes) return DURATION_UNITS.MINUTES;
  if (minutes % (24 * 60) === 0) return DURATION_UNITS.DAYS;
  if (minutes % 60 === 0) return DURATION_UNITS.HOURS;
  return DURATION_UNITS.MINUTES;
};

watch(
  () => props.initialData,
  data => {
    if (!data || !Object.keys(data).length) return;
    name.value = data.name ?? '';
    enabled.value = data.enabled ?? true;
    reengagementMessage.value = data.reengagementMessage ?? '';
    reengagementInterval.value = data.reengagementInterval ?? null;
    reengagementUnit.value = unitFromMinutes(data.reengagementInterval);
    autoResolveDuration.value = data.autoResolveDuration ?? null;
    autoResolveUnit.value = unitFromMinutes(data.autoResolveDuration);
    autoResolveMessage.value = data.autoResolveMessage ?? '';
    autoResolveIgnoreWaiting.value = data.autoResolveIgnoreWaiting ?? false;
    noClientLabel.value = labelOptions.value.find(o => o.name === data.noClientInteractionLabel) ?? null;
    noAgentLabel.value = labelOptions.value.find(o => o.name === data.noAgentInteractionLabel) ?? null;
  },
  { immediate: true, deep: true }
);

const REENGAGEMENT_INTERVAL_MIN = 5;

const reengagementIntervalError = computed(() => {
  const val = reengagementInterval.value;
  if (val !== null && val < REENGAGEMENT_INTERVAL_MIN) {
    return T('FORM.REENGAGEMENT_INTERVAL_MIN_ERROR');
  }
  return null;
});

const hasErrors = computed(() => !!reengagementIntervalError.value);

const handleSubmit = () => {
  if (hasErrors.value) return;
  emit('submit', {
    name: name.value,
    enabled: enabled.value,
    reengagement_message: reengagementMessage.value || null,
    reengagement_interval: reengagementInterval.value || null,
    auto_resolve_duration: autoResolveDuration.value || null,
    auto_resolve_message: autoResolveMessage.value || null,
    auto_resolve_ignore_waiting: autoResolveIgnoreWaiting.value,
    no_client_interaction_label: noClientLabel.value?.name ?? null,
    no_agent_interaction_label: noAgentLabel.value?.name ?? null,
  });
};

const T = key => t(`CONVERSATION_FLOWS.${key}`);
</script>

<template>
  <form class="grid gap-5 w-full" @submit.prevent="handleSubmit">
    <!-- Nome e status -->
    <div class="flex gap-4 items-end">
      <WithLabel :label="T('FORM.FLOW_NAME')" class="flex-1">
        <Input
          v-model="name"
          :placeholder="T('FORM.FLOW_NAME_PLACEHOLDER')"
          required
          class="w-full"
        />
      </WithLabel>
      <WithLabel :label="T('FORM.ENABLED')">
        <div class="h-9 flex items-center">
          <Switch v-model="enabled" />
        </div>
      </WithLabel>
    </div>

    <!-- Reengajamento -->
    <WithLabel :label="T('FORM.REENGAGEMENT_MESSAGE_LABEL')" :help-message="T('FORM.REENGAGEMENT_SECTION_DESC')">
      <TextArea
        v-model="reengagementMessage"
        :placeholder="T('FORM.REENGAGEMENT_MESSAGE_PLACEHOLDER')"
        class="w-full"
      />
    </WithLabel>

    <WithLabel :label="T('FORM.REENGAGEMENT_INTERVAL_LABEL')">
      <div class="flex flex-col gap-1 w-full">
        <div class="gap-2 w-full grid grid-cols-[3fr_1fr]">
          <DurationInput
            v-model="reengagementInterval"
            v-model:unit="reengagementUnit"
            min="0"
            max="1438560"
            class="w-full"
          />
        </div>
        <p v-if="reengagementIntervalError" class="text-body-xs text-n-ruby-11 flex items-center gap-1">
          <span class="i-lucide-alert-circle size-3.5 flex-shrink-0" />
          {{ reengagementIntervalError }}
        </p>
      </div>
    </WithLabel>

    <!-- Resolução automática -->
    <WithLabel :label="T('FORM.DURATION_LABEL')" :help-message="T('FORM.RESOLUTION_SECTION_DESC')">
      <div class="gap-2 w-full grid grid-cols-[3fr_1fr]">
        <DurationInput
          v-model="autoResolveDuration"
          v-model:unit="autoResolveUnit"
          min="0"
          max="1438560"
          class="w-full"
        />
      </div>
    </WithLabel>

    <WithLabel :label="T('FORM.MESSAGE_LABEL')">
      <TextArea
        v-model="autoResolveMessage"
        :placeholder="T('FORM.MESSAGE_PLACEHOLDER')"
        class="w-full"
      />
    </WithLabel>

    <!-- Preferências e etiquetas -->
    <WithLabel :label="T('FORM.LABELS_SECTION')" :help-message="T('FORM.LABELS_SECTION_DESC')">
      <div class="rounded-xl border border-n-weak bg-n-solid-1 w-full text-sm text-n-slate-12 divide-y divide-n-weak">
        <div class="p-3 h-12 flex items-center justify-between">
          <span>{{ T('FORM.IGNORE_WAITING') }}</span>
          <Switch v-model="autoResolveIgnoreWaiting" />
        </div>
        <div class="p-3 h-12 flex items-center justify-between">
          <span>{{ T('FORM.NO_CLIENT_LABEL') }}</span>
          <SingleSelect
            v-model="noClientLabel"
            :options="labelOptions"
            :placeholder="T('FORM.LABEL_PLACEHOLDER')"
            placeholder-icon="i-lucide-chevron-down"
            placeholder-trailing-icon
            variant="faded"
          />
        </div>
        <div class="p-3 h-12 flex items-center justify-between">
          <span>{{ T('FORM.NO_AGENT_LABEL') }}</span>
          <SingleSelect
            v-model="noAgentLabel"
            :options="labelOptions"
            :placeholder="T('FORM.LABEL_PLACEHOLDER')"
            placeholder-icon="i-lucide-chevron-down"
            placeholder-trailing-icon
            variant="faded"
          />
        </div>
      </div>
    </WithLabel>

    <div class="flex gap-2">
      <NextButton blue type="submit" :is-loading="isLoading" :disabled="hasErrors">
        {{ mode === 'CREATE' ? T('FORM.SUBMIT_CREATE') : T('FORM.SUBMIT_EDIT') }}
      </NextButton>
      <NextButton type="button" @click="$emit('cancel')">
        {{ T('FORM.CANCEL') }}
      </NextButton>
    </div>
  </form>
</template>
