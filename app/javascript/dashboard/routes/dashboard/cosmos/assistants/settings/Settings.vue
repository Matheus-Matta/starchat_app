<script setup>
import { computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import SettingsPageLayout from 'dashboard/components-next/cosmos/SettingsPageLayout.vue';
import SettingsHeader from 'dashboard/components-next/cosmos/pageComponents/settings/SettingsHeader.vue';
import AssistantBasicSettingsForm from 'dashboard/components-next/cosmos/pageComponents/assistant/settings/AssistantBasicSettingsForm.vue';
import AssistantSystemSettingsForm from 'dashboard/components-next/cosmos/pageComponents/assistant/settings/AssistantSystemSettingsForm.vue';
import AssistantControlItems from 'dashboard/components-next/cosmos/pageComponents/assistant/settings/AssistantControlItems.vue';

const { t } = useI18n();
const route = useRoute();
const store = useStore();
const assistantId = route.params.assistantId;
const uiFlags = useMapGetter('cosmosAssistants/getUIFlags');
const isFetching = computed(() => uiFlags.value.fetchingItem);
const assistant = computed(() =>
  store.getters['cosmosAssistants/getRecord'](Number(assistantId))
);

const isAssistantAvailable = computed(() => !!assistant.value?.id);

const controlItems = computed(() => {
  return [
    {
      name: t(
        'COSMOS.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.GUARDRAILS.TITLE'
      ),
      description: t(
        'COSMOS.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.GUARDRAILS.DESCRIPTION'
      ),
      routeName: 'cosmos_assistants_guardrails_index',
    },
    {
      name: t(
        'COSMOS.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.SCENARIOS.TITLE'
      ),
      description: t(
        'COSMOS.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.SCENARIOS.DESCRIPTION'
      ),
      routeName: 'cosmos_assistants_scenarios_index',
    },
    {
      name: t(
        'COSMOS.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.RESPONSE_GUIDELINES.TITLE'
      ),
      description: t(
        'COSMOS.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.RESPONSE_GUIDELINES.DESCRIPTION'
      ),
      routeName: 'cosmos_assistants_guidelines_index',
    },
  ];
});

const breadcrumbItems = computed(() => {
  const activeControlItem = controlItems.value?.find(
    item => item.routeName === route.name
  );

  return [
    {
      label: t('COSMOS.ASSISTANTS.SETTINGS.BREADCRUMB.ASSISTANT'),
      routeName: 'cosmos_assistants_index',
    },
    { label: assistant.value?.name, routeName: 'cosmos_assistants_edit' },
    ...(activeControlItem
      ? [
          {
            label: activeControlItem.name,
            routeName: activeControlItem.routeName,
          },
        ]
      : []),
  ];
});

const handleSubmit = async updatedAssistant => {
  try {
    await store.dispatch('cosmosAssistants/update', {
      id: assistantId,
      ...updatedAssistant,
    });
    useAlert(t('COSMOS.ASSISTANTS.EDIT.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('COSMOS.ASSISTANTS.EDIT.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};

onMounted(() => {
  if (!isAssistantAvailable.value) {
    store.dispatch('cosmosAssistants/show', assistantId);
  }
});
</script>

<template>
  <SettingsPageLayout
    :breadcrumb-items="breadcrumbItems"
    :is-fetching="isFetching"
    class="[&>div]:max-w-[80rem]"
  >
    <template #body>
      <div class="flex flex-col gap-6">
        <div class="flex flex-col gap-6">
          <SettingsHeader
            :heading="t('COSMOS.ASSISTANTS.SETTINGS.BASIC_SETTINGS.TITLE')"
            :description="
              t('COSMOS.ASSISTANTS.SETTINGS.BASIC_SETTINGS.DESCRIPTION')
            "
          />
          <AssistantBasicSettingsForm
            :assistant="assistant"
            @submit="handleSubmit"
          />
        </div>
        <span class="h-px w-full bg-n-weak mt-2" />
        <div class="flex flex-col gap-6">
          <SettingsHeader
            :heading="t('COSMOS.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.TITLE')"
            :description="
              t('COSMOS.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.DESCRIPTION')
            "
          />
          <AssistantSystemSettingsForm
            :assistant="assistant"
            @submit="handleSubmit"
          />
        </div>
      </div>
    </template>
    <template #controls>
      <div class="flex flex-col gap-6">
        <SettingsHeader
          :heading="t('COSMOS.ASSISTANTS.SETTINGS.CONTROL_ITEMS.TITLE')"
          :description="
            t('COSMOS.ASSISTANTS.SETTINGS.CONTROL_ITEMS.DESCRIPTION')
          "
        />
        <div class="flex flex-col gap-6">
          <AssistantControlItems
            v-for="item in controlItems"
            :key="item.name"
            :control-item="item"
          />
        </div>
      </div>
    </template>
  </SettingsPageLayout>
</template>
