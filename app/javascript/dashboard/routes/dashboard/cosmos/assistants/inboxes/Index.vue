<script setup>
import { computed, onBeforeMount, onMounted, ref, nextTick } from 'vue';
import {
  useMapGetter,
  useStore,
  useStoreGetters,
} from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import BackButton from 'dashboard/components/widgets/BackButton.vue';
import DeleteDialog from 'dashboard/components-next/cosmos/pageComponents/DeleteDialog.vue';
import PageLayout from 'dashboard/components-next/cosmos/PageLayout.vue';
import ConnectInboxDialog from 'dashboard/components-next/cosmos/pageComponents/inbox/ConnectInboxDialog.vue';
import InboxCard from 'dashboard/components-next/cosmos/assistant/InboxCard.vue';
import InboxPageEmptyState from 'dashboard/components-next/cosmos/pageComponents/emptyStates/InboxPageEmptyState.vue';

const store = useStore();
const dialogType = ref('');
const route = useRoute();
const assistantUiFlags = useMapGetter('cosmosAssistants/getUIFlags');
const uiFlags = useMapGetter('cosmosInboxes/getUIFlags');
const isFetchingAssistant = computed(() => assistantUiFlags.value.fetchingItem);
const isFetching = computed(() => uiFlags.value.fetchingList);

const cosmosInboxes = useMapGetter('cosmosInboxes/getRecords');

const selectedInbox = ref(null);
const disconnectInboxDialog = ref(null);

const handleDelete = () => {
  disconnectInboxDialog.value.dialogRef.open();
};

const connectInboxDialog = ref(null);

const handleCreate = () => {
  dialogType.value = 'create';
  nextTick(() => connectInboxDialog.value.dialogRef.open());
};
const handleAction = ({ action, id }) => {
  selectedInbox.value = cosmosInboxes.value.find(inbox => id === inbox.id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    }
  });
};

const handleCreateClose = () => {
  dialogType.value = '';
  selectedInbox.value = null;
};

const getters = useStoreGetters();
const assistantId = Number(route.params.assistantId);
const assistant = computed(() =>
  getters['cosmosAssistants/getRecord'].value(assistantId)
);
onBeforeMount(() => store.dispatch('cosmosAssistants/show', assistantId));

onMounted(() =>
  store.dispatch('cosmosInboxes/get', {
    assistantId: assistantId,
  })
);
</script>

<template>
  <PageLayout
    :button-label="$t('COSMOS.INBOXES.ADD_NEW')"
    :button-policy="['administrator']"
    :is-fetching="isFetchingAssistant || isFetching"
    :is-empty="!cosmosInboxes.length"
    :show-pagination-footer="false"
    :feature-flag="FEATURE_FLAGS.COSMOS"
    @click="handleCreate"
  >
    <template v-if="!isFetchingAssistant" #headerTitle>
      <div class="flex flex-row items-center gap-4">
        <BackButton compact />
        <span
          class="flex items-center gap-1 text-lg font-medium text-n-slate-12"
        >
          {{ assistant.name }}
          <span class="i-lucide-chevron-right text-xl text-n-slate-10" />
          {{ $t('COSMOS.INBOXES.HEADER') }}
        </span>
      </div>
    </template>

    <template #emptyState>
      <InboxPageEmptyState @click="handleCreate" />
    </template>

    <template #body>
      <div class="flex flex-col gap-4">
        <InboxCard
          v-for="cosmosInbox in cosmosInboxes"
          :id="cosmosInbox.id"
          :key="cosmosInbox.id"
          :inbox="cosmosInbox"
          @action="handleAction"
        />
      </div>
    </template>

    <DeleteDialog
      v-if="selectedInbox"
      ref="disconnectInboxDialog"
      :entity="selectedInbox"
      :delete-payload="{
        assistantId: assistantId,
        inboxId: selectedInbox.id,
      }"
      type="Inboxes"
    />

    <ConnectInboxDialog
      v-if="dialogType"
      ref="connectInboxDialog"
      :assistant-id="assistantId"
      :type="dialogType"
      @close="handleCreateClose"
    />
  </PageLayout>
</template>
