<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useStore, useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const store = useStore();
const getters = useStoreGetters();
const allLabels = useMapGetter('labels/getLabels');

const campaignId = computed(() => Number(route.params.id));

const campaign = computed(() => {
  const all = getters['campaigns/getAllCampaigns'].value;
  return all.find(c => c.id === campaignId.value) || null;
});

const isLoadingContacts = ref(false);
const contactsData = ref({ meta: null, payload: [] });

const previewCount = ref(null);
const previewContactsList = ref([]);
const previewMeta = ref({ current_page: 1, total_pages: 1 });
const isLoadingPreview = ref(false);
const isLoadingMorePreview = ref(false);

const isConfirming = ref(false);
const confirmError = ref('');
const confirmSuccess = ref('');

const isDraft = computed(() => campaign.value?.campaign_status === 'draft');
const isCompleted = computed(() => campaign.value?.campaign_status === 'completed');
const isActive = computed(() => campaign.value?.campaign_status === 'active');

const statusLabel = computed(() => {
  if (!campaign.value) return '';
  return t(`CAMPAIGN.DETAIL.STATUS.${campaign.value.campaign_status.toUpperCase()}`);
});

const statusClass = computed(() => {
  if (isDraft.value) return 'bg-n-yellow-3 text-n-yellow-11 border border-n-yellow-6';
  if (isCompleted.value) return 'bg-n-slate-3 text-n-slate-11 border border-n-weak';
  return 'bg-n-teal-3 text-n-teal-11 border border-n-teal-6';
});

const audienceLabels = computed(() => {
  if (!campaign.value?.audience?.length) return '—';
  const labelsMap = Object.fromEntries((allLabels.value || []).map(l => [l.id, l.title]));
  return campaign.value.audience.map(a => labelsMap[a.id] || `Label #${a.id}`).join(', ');
});

const scheduledAtFormatted = computed(() => {
  if (!campaign.value?.scheduled_at) return '—';
  return new Date(campaign.value.scheduled_at * 1000).toLocaleString();
});

const hasMorePreviewPages = computed(
  () => previewMeta.value.current_page < previewMeta.value.total_pages
);

const goBack = () => router.back();

const fetchPreviewCount = async (page = 1) => {
  if (!campaign.value?.audience?.length) return;
  if (page === 1) {
    isLoadingPreview.value = true;
    previewContactsList.value = [];
  } else {
    isLoadingMorePreview.value = true;
  }
  const data = await store.dispatch('campaigns/previewContacts', {
    audience: campaign.value.audience,
    page,
  });
  previewCount.value = data.count ?? 0;
  previewContactsList.value = page === 1
    ? (data.contacts ?? [])
    : [...previewContactsList.value, ...(data.contacts ?? [])];
  previewMeta.value = data.meta ?? { current_page: page, total_pages: 1 };
  isLoadingPreview.value = false;
  isLoadingMorePreview.value = false;
};

const loadMorePreview = () => fetchPreviewCount(previewMeta.value.current_page + 1);

const fetchContacts = async (page = 1) => {
  if (!campaignId.value) return;
  isLoadingContacts.value = true;
  try {
    const data = await store.dispatch('campaigns/getContacts', { id: campaignId.value, page });
    contactsData.value = page === 1
      ? data.data
      : { meta: data.data.meta, payload: [...contactsData.value.payload, ...data.data.payload] };
  } finally {
    isLoadingContacts.value = false;
  }
};

const handleConfirm = async () => {
  confirmError.value = '';
  confirmSuccess.value = '';
  isConfirming.value = true;
  try {
    await store.dispatch('campaigns/confirm', campaignId.value);
    confirmSuccess.value = t('CAMPAIGN.DETAIL.DRAFT_SECTION.API.SUCCESS_MESSAGE');
  } catch {
    confirmError.value = t('CAMPAIGN.DETAIL.DRAFT_SECTION.API.ERROR_MESSAGE');
  } finally {
    isConfirming.value = false;
  }
};

const loadMoreContacts = () =>
  fetchContacts((contactsData.value.meta?.current_page || 1) + 1);

const hasMoreContactPages = computed(() => {
  const { meta } = contactsData.value;
  return meta ? meta.current_page < meta.total_pages : false;
});

const statusIcon = status => {
  if (status === 'sent') return 'i-lucide-check-circle-2';
  if (status === 'failed') return 'i-lucide-x-circle';
  return 'i-lucide-clock-3';
};

const statusBadgeClass = status => {
  if (status === 'sent') return 'bg-n-teal-3 text-n-teal-11';
  if (status === 'failed') return 'bg-n-ruby-3 text-n-ruby-11';
  return 'bg-n-slate-3 text-n-slate-11';
};

onMounted(async () => {
  const fetches = [];
  if (!campaign.value) fetches.push(store.dispatch('campaigns/get'));
  if (!allLabels.value?.length) fetches.push(store.dispatch('labels/get'));
  await Promise.all(fetches);

  if (isDraft.value || isActive.value) fetchPreviewCount();
  if (isCompleted.value) fetchContacts();
});

watch(campaign, newCampaign => {
  if (!newCampaign) return;
  if (newCampaign.campaign_status === 'completed' && !contactsData.value.payload.length) {
    fetchContacts();
  }
  if ((newCampaign.campaign_status === 'draft' || newCampaign.campaign_status === 'active') && previewCount.value === null) {
    fetchPreviewCount();
  }
});
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto">

    <!-- Settings-style sticky header -->
    <header class="sticky top-0 z-20 flex items-center justify-between px-6 min-h-[3.5rem] py-3 bg-n-surface-1 border-b border-n-weak">
      <div class="flex items-center gap-3">
        <Button
          variant="ghost"
          size="sm"
          color="slate"
          icon="i-lucide-arrow-left"
          class="-ml-1"
          @click="goBack"
        />
        <div class="w-px h-5 bg-n-weak" />
        <h1 class="text-xl font-medium text-n-slate-12 truncate max-w-md">
          {{ campaign?.title || '...' }}
        </h1>
        <span
          v-if="campaign"
          class="shrink-0 text-xs font-semibold px-2.5 py-0.5 rounded-full"
          :class="statusClass"
        >
          {{ statusLabel }}
        </span>
      </div>

      <!-- Confirm button in header (draft only) -->
      <div v-if="isDraft" class="flex items-center gap-3">
        <span v-if="confirmSuccess" class="text-xs text-n-teal-11 font-medium">{{ confirmSuccess }}</span>
        <span v-if="confirmError" class="text-xs text-n-ruby-11 font-medium">{{ confirmError }}</span>
        <Button
          :label="t('CAMPAIGN.DETAIL.DRAFT_SECTION.CONFIRM_BUTTON')"
          icon="i-lucide-send"
          size="sm"
          :is-loading="isConfirming"
          :disabled="isConfirming || !!confirmSuccess"
          @click="handleConfirm"
        />
      </div>
    </header>

    <div v-if="!campaign" class="flex justify-center py-20">
      <Spinner />
    </div>

    <template v-else>
      <div class="flex flex-col gap-8 px-6 py-6 max-w-5xl w-full mx-auto">

        <!-- Campaign info: 3-col key-value row -->
        <div class="grid grid-cols-3 gap-6">
          <div class="flex flex-col gap-1">
            <span class="text-xs font-semibold text-n-slate-9 uppercase tracking-wider">
              {{ t('CAMPAIGN.DETAIL.INFO.INBOX') }}
            </span>
            <span class="text-sm font-medium text-n-slate-12">{{ campaign.inbox?.name || '—' }}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs font-semibold text-n-slate-9 uppercase tracking-wider">
              {{ t('CAMPAIGN.DETAIL.INFO.SCHEDULED_AT') }}
            </span>
            <span class="text-sm text-n-slate-12">{{ scheduledAtFormatted }}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs font-semibold text-n-slate-9 uppercase tracking-wider">
              {{ t('CAMPAIGN.DETAIL.INFO.AUDIENCE') }}
            </span>
            <span class="text-sm text-n-slate-12">{{ audienceLabels }}</span>
          </div>
          <div v-if="campaign.message" class="col-span-3 flex flex-col gap-1">
            <span class="text-xs font-semibold text-n-slate-9 uppercase tracking-wider">
              {{ t('CAMPAIGN.DETAIL.INFO.MESSAGE') }}
            </span>
            <p class="text-sm text-n-slate-12 leading-relaxed whitespace-pre-line">{{ campaign.message }}</p>
          </div>
        </div>

        <div class="w-full h-px bg-n-weak" />

        <!-- Audience preview (draft or active) -->
        <section v-if="isDraft || isActive">
          <!-- Section title row -->
          <div class="flex items-center justify-between mb-5">
            <div class="flex items-center gap-3">
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('CAMPAIGN.DETAIL.DRAFT_SECTION.TITLE') }}
              </h2>
              <Spinner v-if="isLoadingPreview" class="w-4 h-4 text-n-slate-9" />
              <span
                v-else-if="previewCount !== null"
                class="text-xs font-semibold px-2.5 py-1 rounded-full"
                :class="isDraft ? 'bg-n-yellow-3 text-n-yellow-11' : 'bg-n-teal-3 text-n-teal-11'"
              >
                {{ previewCount }} contatos
              </span>
            </div>
          </div>

          <!-- Contact rows — same style as ContactsCard / CardLayout -->
          <div v-if="isLoadingPreview" class="flex justify-center py-10">
            <Spinner />
          </div>
          <div
            v-else-if="previewContactsList.length === 0 && previewCount !== null"
            class="flex flex-col items-center justify-center py-12 gap-2 text-n-slate-9"
          >
            <i class="i-lucide-users w-8 h-8" />
            <p class="text-sm">Nenhum contato encontrado para as etiquetas selecionadas.</p>
          </div>
          <div v-else class="flex flex-col gap-3">
            <div
              v-for="contact in previewContactsList"
              :key="contact.id"
              class="flex w-full gap-4 px-5 py-4 items-center outline-1 outline outline-n-container -outline-offset-1 rounded-xl bg-n-solid-2"
            >
              <Avatar :name="contact.name || '?'" :size="40" rounded-full />
              <div class="flex flex-col gap-0.5 flex-1 min-w-0">
                <span class="text-sm font-medium text-n-slate-12 truncate">
                  {{ contact.name || '—' }}
                </span>
                <div class="flex flex-wrap items-center gap-x-2 gap-y-0.5">
                  <span v-if="contact.email" class="text-xs text-n-slate-10 truncate max-w-48">
                    {{ contact.email }}
                  </span>
                  <span
                    v-if="contact.email && contact.phone_number"
                    class="w-px h-3 bg-n-slate-6 shrink-0"
                  />
                  <span v-if="contact.phone_number" class="text-xs text-n-slate-10">
                    {{ contact.phone_number }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Load more -->
            <div v-if="hasMorePreviewPages" class="flex justify-center pt-1">
              <Button
                :label="t('CAMPAIGN.DETAIL.CONTACTS.LOAD_MORE')"
                :is-loading="isLoadingMorePreview"
                variant="faded"
                color="slate"
                size="sm"
                @click="loadMorePreview"
              />
            </div>
          </div>
        </section>

        <!-- Delivery report (completed or active with sent contacts) -->
        <section v-if="isCompleted || (isActive && contactsData.payload.length)">
          <!-- Stats row -->
          <div class="flex items-center justify-between mb-5">
            <h2 class="text-base font-semibold text-n-slate-12">
              {{ t('CAMPAIGN.DETAIL.CONTACTS.TITLE') }}
            </h2>
          </div>
          <div class="grid grid-cols-4 gap-3 mb-6">
            <div class="flex flex-col gap-0.5 px-4 py-3 rounded-xl outline-1 outline outline-n-container -outline-offset-1 bg-n-solid-2">
              <span class="text-xl font-bold text-n-slate-12">{{ campaign.contacts_count || 0 }}</span>
              <span class="text-xs text-n-slate-10">{{ t('CAMPAIGN.DETAIL.CONTACTS.TOTAL') }}</span>
            </div>
            <div class="flex flex-col gap-0.5 px-4 py-3 rounded-xl bg-n-teal-2 outline-1 outline outline-n-teal-6 -outline-offset-1">
              <span class="text-xl font-bold text-n-teal-11">{{ campaign.sent_count || 0 }}</span>
              <span class="text-xs text-n-teal-10">{{ t('CAMPAIGN.DETAIL.CONTACTS.SENT') }}</span>
            </div>
            <div class="flex flex-col gap-0.5 px-4 py-3 rounded-xl bg-n-ruby-2 outline-1 outline outline-n-ruby-6 -outline-offset-1">
              <span class="text-xl font-bold text-n-ruby-11">{{ campaign.failed_count || 0 }}</span>
              <span class="text-xs text-n-ruby-10">{{ t('CAMPAIGN.DETAIL.CONTACTS.FAILED') }}</span>
            </div>
            <div class="flex flex-col gap-0.5 px-4 py-3 rounded-xl outline-1 outline outline-n-container -outline-offset-1 bg-n-solid-2">
              <span class="text-xl font-bold text-n-slate-11">{{ campaign.pending_count || 0 }}</span>
              <span class="text-xs text-n-slate-10">{{ t('CAMPAIGN.DETAIL.CONTACTS.PENDING') }}</span>
            </div>
          </div>

          <!-- Delivery contact rows -->
          <div v-if="isLoadingContacts && !contactsData.payload.length" class="flex justify-center py-10">
            <Spinner />
          </div>
          <div
            v-else-if="contactsData.payload.length === 0"
            class="flex flex-col items-center justify-center py-12 gap-2 text-n-slate-9"
          >
            <i class="i-lucide-inbox w-8 h-8" />
            <p class="text-sm">{{ t('CAMPAIGN.DETAIL.CONTACTS.EMPTY') }}</p>
          </div>
          <div v-else class="flex flex-col gap-3">
            <div
              v-for="item in contactsData.payload"
              :key="item.id"
              class="flex w-full gap-4 px-5 py-4 items-center outline-1 outline outline-n-container -outline-offset-1 rounded-xl bg-n-solid-2"
            >
              <Avatar :name="item.contact?.name || '?'" :size="40" rounded-full />
              <div class="flex flex-col gap-0.5 flex-1 min-w-0">
                <span class="text-sm font-medium text-n-slate-12 truncate">
                  {{ item.contact?.name || '—' }}
                </span>
                <div class="flex flex-wrap items-center gap-x-2 gap-y-0.5">
                  <span v-if="item.contact?.email" class="text-xs text-n-slate-10 truncate max-w-48">
                    {{ item.contact.email }}
                  </span>
                  <span
                    v-if="item.contact?.email && item.contact?.phone_number"
                    class="w-px h-3 bg-n-slate-6 shrink-0"
                  />
                  <span v-if="item.contact?.phone_number" class="text-xs text-n-slate-10">
                    {{ item.contact.phone_number }}
                  </span>
                </div>
              </div>
              <div class="flex flex-col items-end gap-1 shrink-0">
                <span
                  class="inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-full"
                  :class="statusBadgeClass(item.status)"
                >
                  <i :class="statusIcon(item.status)" class="w-3.5 h-3.5" />
                  {{ t(`CAMPAIGN.DETAIL.CONTACTS.STATUS.${item.status.toUpperCase()}`) }}
                </span>
                <span v-if="item.sent_at" class="text-xs text-n-slate-9">
                  {{ new Date(item.sent_at).toLocaleString() }}
                </span>
                <span v-if="item.status === 'failed' && item.error_message" class="text-xs text-n-ruby-10 max-w-48 text-right truncate">
                  {{ item.error_message }}
                </span>
              </div>
            </div>

            <div v-if="hasMoreContactPages" class="flex justify-center pt-1">
              <Button
                :label="t('CAMPAIGN.DETAIL.CONTACTS.LOAD_MORE')"
                :is-loading="isLoadingContacts"
                variant="faded"
                color="slate"
                size="sm"
                @click="loadMoreContacts"
              />
            </div>
          </div>
        </section>

      </div>
    </template>
  </div>
</template>
