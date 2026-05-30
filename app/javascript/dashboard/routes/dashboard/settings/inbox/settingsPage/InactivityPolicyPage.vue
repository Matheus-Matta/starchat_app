<script setup>
import { h, ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import SettingsSection from '../../../../../components/SettingsSection.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import TextArea from 'next/textarea/TextArea.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DurationInput from 'next/input/DurationInput.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();

const duration = ref(0);
const unit = ref(DURATION_UNITS.MINUTES);
const message = ref('');
const labelToApply = ref({});
const ignoreWaiting = ref(false);
const isEnabled = ref(false);
const isSubmitting = ref(false);

const labels = useMapGetter('labels/getLabels');

const labelOptions = computed(() =>
  labels.value?.length
    ? labels.value.map(label => ({
        id: label.title,
        name: label.title,
        icon: h('span', {
          class: `size-[12px] ring-1 ring-n-alpha-1 dark:ring-white/20 ring-inset rounded-sm`,
          style: { backgroundColor: label.color },
        }),
      }))
    : []
);

const selectedLabelName = computed(() => {
  return labelToApply.value?.name ?? null;
});

watch(
  [() => props.inbox, labelOptions],
  () => {
    const {
      auto_resolve_duration,
      auto_resolve_message,
      auto_resolve_ignore_waiting,
      auto_resolve_label,
    } = props.inbox || {};

    duration.value = auto_resolve_duration;
    message.value = auto_resolve_message;
    ignoreWaiting.value = auto_resolve_ignore_waiting;

    // find the correct label option from the list
    labelToApply.value = labelOptions.value.find(
      option => option.name === auto_resolve_label
    );

    // Set unit based on duration
    if (duration.value) {
      if (duration.value % (24 * 60) === 0) {
        unit.value = DURATION_UNITS.DAYS;
      } else if (duration.value % 60 === 0) {
        unit.value = DURATION_UNITS.HOURS;
      } else {
        unit.value = DURATION_UNITS.MINUTES;
      }
      isEnabled.value = true;
    } else {
      isEnabled.value = false;
    }
  },
  { deep: true, immediate: true }
);

const updateInboxSettings = async settings => {
  try {
    isSubmitting.value = true;
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      channel: {},
      ...settings,
    });
    useAlert(t('INBOX_MGMT.INACTIVITY_POLICY.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};

const handleSubmit = async () => {
  if (duration.value && duration.value < 10) {
    useAlert(
      t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.DURATION.ERROR') ||
        'A duração deve ser no mínimo 10 minutos'
    );
    return Promise.resolve();
  }

  return updateInboxSettings({
    auto_resolve_duration: duration.value,
    auto_resolve_message: message.value,
    auto_resolve_ignore_waiting: ignoreWaiting.value,
    auto_resolve_label: selectedLabelName.value,
  });
};

const handleDisable = async () => {
  duration.value = null;
  message.value = '';
  ignoreWaiting.value = false;
  labelToApply.value = null;

  return updateInboxSettings({
    auto_resolve_duration: null,
    auto_resolve_message: '',
    auto_resolve_ignore_waiting: false,
    auto_resolve_label: null,
  });
};

const toggleAutoResolve = async () => {
  if (!isEnabled.value) {
    handleDisable();
  }
};
</script>

<template>
  <div class="mx-8 mt-2">
    <SettingsSection
      :title="t('INBOX_MGMT.INACTIVITY_POLICY.TITLE')"
      :sub-title="t('INBOX_MGMT.INACTIVITY_POLICY.SUBTITLE')"
      with-border
    >
      <div
        class="flex justify-between items-center bg-n-alpha-1 p-3 rounded-md mb-4 border border-n-weak"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('INBOX_MGMT.INACTIVITY_POLICY.ENABLE_OVERRIDE') }}
        </span>
        <Switch v-model="isEnabled" @change="toggleAutoResolve" />
      </div>

      <form
        v-if="isEnabled"
        class="grid gap-5 max-w-lg"
        @submit.prevent="handleSubmit"
      >
        <WithLabel :label="t('INBOX_MGMT.INACTIVITY_POLICY.DURATION_LABEL')">
          <div class="gap-2 w-full grid grid-cols-[3fr_1fr]">
            <DurationInput
              v-model="duration"
              v-model:unit="unit"
              min="0"
              max="1438560"
              class="w-full"
            />
          </div>
        </WithLabel>

        <WithLabel :label="t('INBOX_MGMT.INACTIVITY_POLICY.MESSAGE_LABEL')">
          <TextArea
            v-model="message"
            class="w-full"
            :placeholder="t('INBOX_MGMT.INACTIVITY_POLICY.MESSAGE_PLACEHOLDER')"
          />
        </WithLabel>

        <WithLabel
          :label="
            t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.PREFERENCES') || 'Preferences'
          "
        >
          <div
            class="rounded-xl border border-n-weak bg-n-solid-1 w-full text-sm text-n-slate-12 divide-y divide-n-weak"
          >
            <div class="p-3 h-12 flex items-center justify-between">
              <span>
                {{ t('INBOX_MGMT.INACTIVITY_POLICY.IGNORE_WAITING_LABEL') }}
              </span>
              <Switch v-model="ignoreWaiting" />
            </div>
            <div class="p-3 h-12 flex items-center justify-between">
              <span>
                {{ t('INBOX_MGMT.INACTIVITY_POLICY.LABEL_LABEL') }}
              </span>
              <SingleSelect
                v-model="labelToApply"
                :options="labelOptions"
                :placeholder="
                  t('INBOX_MGMT.INACTIVITY_POLICY.LABEL_PLACEHOLDER')
                "
                placeholder-icon="i-lucide-chevron-down"
                placeholder-trailing-icon
                variant="faded"
              />
            </div>
          </div>
        </WithLabel>

        <div class="flex gap-2">
          <NextButton
            blue
            type="submit"
            :is-loading="isSubmitting"
            :label="t('INBOX_MGMT.INACTIVITY_POLICY.SAVE')"
          />
        </div>
      </form>

      <div v-else class="text-sm text-n-slate-11 mt-2">
        {{ t('INBOX_MGMT.INACTIVITY_POLICY.INHERITANCE_NOTE') }}
      </div>
    </SettingsSection>
  </div>
</template>
