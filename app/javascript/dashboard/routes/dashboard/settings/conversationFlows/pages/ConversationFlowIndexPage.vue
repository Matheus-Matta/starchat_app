<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import ConversationFlowForm from './ConversationFlowForm.vue';

const store = useStore();
const { t } = useI18n();

const conversationFlows = useMapGetter('conversationFlows/getConversationFlows');
const uiFlags = useMapGetter('conversationFlows/getUIFlags');

const showForm = ref(false);
const editingFlow = ref(null);
const deletingFlowId = ref(null);

const T = key => t(`CONVERSATION_FLOWS.${key}`);

const openCreate = () => {
  editingFlow.value = null;
  showForm.value = true;
};

const openEdit = flow => {
  editingFlow.value = flow;
  showForm.value = true;
};

const closeForm = () => {
  showForm.value = false;
  editingFlow.value = null;
};

const handleSubmit = async params => {
  try {
    if (editingFlow.value) {
      await store.dispatch('conversationFlows/update', { id: editingFlow.value.id, ...params });
      useAlert(T('UPDATE.SUCCESS'));
    } else {
      await store.dispatch('conversationFlows/create', params);
      useAlert(T('CREATE.SUCCESS'));
    }
    closeForm();
  } catch {
    useAlert(editingFlow.value ? T('UPDATE.ERROR') : T('CREATE.ERROR'));
  }
};

const handleDelete = async flowId => {
  if (!window.confirm(T('DELETE.CONFIRM_MESSAGE'))) return;
  deletingFlowId.value = flowId;
  try {
    await store.dispatch('conversationFlows/delete', flowId);
    useAlert(T('DELETE.SUCCESS'));
  } catch {
    useAlert(T('DELETE.ERROR'));
  } finally {
    deletingFlowId.value = null;
  }
};

onMounted(() => {
  store.dispatch('conversationFlows/get');
  store.dispatch('labels/get');
});
</script>

<template>
  <div class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak">
    <!-- Header -->
    <div class="flex flex-col gap-1 px-5 py-4">
      <div class="flex justify-between items-center w-full">
        <h3 class="text-heading-2 text-n-slate-12">{{ T('TITLE') }}</h3>
        <Button v-if="!showForm" icon="i-lucide-plus" md blue @click="openCreate">
          {{ T('NEW_FLOW') }}
        </Button>
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">{{ T('SUBTITLE') }}</p>
    </div>

    <!-- Form panel -->
    <div v-if="showForm" class="px-5 py-4">
      <ConversationFlowForm
        :initial-data="editingFlow ?? {}"
        :mode="editingFlow ? 'EDIT' : 'CREATE'"
        :is-loading="uiFlags.isCreating || uiFlags.isUpdating"
        @submit="handleSubmit"
        @cancel="closeForm"
      />
    </div>

    <!-- Loading -->
    <div v-else-if="uiFlags.isFetching" class="flex justify-center px-5 py-8">
      <span class="i-lucide-loader-2 animate-spin size-5 text-n-slate-11" />
    </div>

    <!-- Empty state -->
    <div v-else-if="conversationFlows.length === 0" class="flex flex-col items-center gap-2 px-5 py-10 text-center">
      <span class="i-lucide-git-branch-plus size-8 text-n-slate-9" />
      <p class="text-body-main text-n-slate-11 mb-0">{{ T('NO_RECORDS_FOUND') }}</p>
    </div>

    <!-- Flow list -->
    <template v-else>
      <div
        v-for="flow in conversationFlows"
        :key="flow.id"
        class="flex items-start justify-between gap-4 px-5 py-4"
      >
        <!-- Left: name + meta -->
        <div class="flex-1 min-w-0 flex flex-col gap-2">
          <!-- Name row + status badge -->
          <div class="flex items-center gap-2 min-w-0">
            <span class="text-body-main font-medium text-n-slate-12 truncate">
              {{ flow.name }}
            </span>
            <Label
              :label="flow.enabled ? T('STATUS_ACTIVE') : T('STATUS_INACTIVE')"
              :color="flow.enabled ? 'teal' : 'slate'"
              compact
            />
          </div>

          <!-- Meta chips -->
          <div class="flex flex-wrap gap-x-4 gap-y-1">
            <span
              v-if="flow.reengagementInterval"
              class="flex items-center gap-1 text-body-xs text-n-slate-11"
            >
              <span class="i-lucide-bell-ring size-3.5 text-n-amber-9 flex-shrink-0" />
              {{ T('META_REENGAGEMENT') }}: {{ flow.reengagementInterval }}min
            </span>

            <span
              v-if="flow.autoResolveDuration"
              class="flex items-center gap-1 text-body-xs text-n-slate-11"
            >
              <span class="i-lucide-clock size-3.5 text-n-blue-9 flex-shrink-0" />
              {{ T('META_RESOLVE') }}: {{ flow.autoResolveDuration }}min
            </span>

            <span
              v-if="flow.inboxIds?.length"
              class="flex items-center gap-1 text-body-xs text-n-slate-11"
            >
              <span class="i-lucide-inbox size-3.5 text-n-slate-9 flex-shrink-0" />
              {{ flow.inboxIds.length }}
              {{ flow.inboxIds.length === 1 ? T('META_INBOX_SINGLE') : T('META_INBOX_PLURAL') }}
            </span>

            <span
              v-if="flow.noClientInteractionLabel"
              class="flex items-center gap-1 text-body-xs text-n-slate-11"
            >
              <span class="i-lucide-tag size-3.5 text-n-teal-9 flex-shrink-0" />
              {{ flow.noClientInteractionLabel }}
            </span>

            <span
              v-if="flow.noAgentInteractionLabel"
              class="flex items-center gap-1 text-body-xs text-n-slate-11"
            >
              <span class="i-lucide-tag size-3.5 text-n-ruby-9 flex-shrink-0" />
              {{ flow.noAgentInteractionLabel }}
            </span>
          </div>
        </div>

        <!-- Right: action buttons -->
        <div class="flex gap-1 items-center flex-shrink-0 mt-0.5">
          <Button
            v-tooltip.top="T('EDIT_TOOLTIP')"
            icon="i-woot-edit-pen"
            slate
            sm
            @click="openEdit(flow)"
          />
          <Button
            v-tooltip.top="T('DELETE_TOOLTIP')"
            icon="i-woot-bin"
            slate
            sm
            :is-loading="deletingFlowId === flow.id"
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            @click="handleDelete(flow.id)"
          />
        </div>
      </div>
    </template>
  </div>
</template>
