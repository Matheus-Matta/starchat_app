<script setup>
import { computed, ref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email as emailValidator } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { downloadTextFile } from 'dashboard/helper/downloadHelper';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import ContactAPI from 'dashboard/api/contacts';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ConversationCard from 'dashboard/components-next/Conversation/ConversationCard/ConversationCard.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const route = useRoute();
const store = useStore();

const conversations = useMapGetter(
  'contactConversations/getAllConversationsByContactId'
);
const contactsById = useMapGetter('contacts/getContactById');
const stateInbox = useMapGetter('inboxes/getInboxById');
const accountLabels = useMapGetter('labels/getLabels');
const accountLabelsValue = computed(() => accountLabels.value);

const uiFlags = useMapGetter('contactConversations/getUIFlags');
const isFetching = computed(() => uiFlags.value.isFetching);

const contactId = computed(() => route.params.contactId);
const contactConversations = computed(() =>
  conversations.value(contactId.value)
);

// ─── Bulk transcript modal state ───────────────────────────────────────────
const showBulkModal = ref(false);
const selectedType = ref('');
const customEmail = ref('');
const isSubmitting = ref(false);

const contact = computed(() => contactsById.value(contactId.value));

const v$ = useVuelidate(
  { customEmail: { required, emailValidator, minLength: minLength(4) } },
  { customEmail }
);

const sentToOtherEmail = computed(() => selectedType.value === 'other');

const isFormValid = computed(() => {
  if (!selectedType.value) return false;
  if (sentToOtherEmail.value) return !!customEmail.value && !v$.value.customEmail.$error;
  return true;
});

const selectedEmailAddress = computed(() => {
  switch (selectedType.value) {
    case 'contact': return contact.value?.email;
    case 'other': return customEmail.value;
    default: return '';
  }
});

const openBulkModal = () => {
  selectedType.value = '';
  customEmail.value = '';
  showBulkModal.value = true;
};

const closeBulkModal = () => {
  showBulkModal.value = false;
};

// ─── Timezone helpers ──────────────────────────────────────────────────────
const tzOffset = () => {
  const pad = n => String(Math.abs(n)).padStart(2, '0');
  const offset = -new Date().getTimezoneOffset();
  const sign = offset >= 0 ? '+' : '-';
  return `${sign}${pad(Math.floor(Math.abs(offset) / 60))}:${pad(Math.abs(offset) % 60)}`;
};

const formatIso = unixSeconds =>
  new Date(unixSeconds * 1000).toISOString().replace('Z', tzOffset());

const formatAttachments = attachments => {
  if (!attachments?.length) return [];
  return attachments.map(att => {
    const typeLabel = (att.file_type || 'file').toUpperCase();
    const url = att.data_url || att.thumb_url || '';
    const ext = att.extension ? `.${att.extension}` : '';
    return `      [${typeLabel}${ext}] ${url}`;
  });
};

// ─── Download all conversations as a single .txt ──────────────────────────
const downloadBulkTranscript = () => {
  const sep = '='.repeat(80);
  const dash = '-'.repeat(80);
  const now = new Date();
  const nowIso = formatIso(now.getTime() / 1000);
  const contactName = contact.value?.name || 'Contact';
  const totalConversations = contactConversations.value.length;

  const fileHeader = [
    sep,
    'TRANSCRIPT COMPLETO DE CONVERSAS',
    sep,
    `Contato     :  ${contactName}`,
    `Total       :  ${totalConversations} conversa(s)`,
    `Exportado   :  ${nowIso}`,
    sep,
    '',
  ].join('\n');

  const body = contactConversations.value
    .map((conv, idx) => {
      const messages = (conv.messages || [])
        .filter(
          msg =>
            !msg.private &&
            (msg.message_type === MESSAGE_TYPE.INCOMING ||
              msg.message_type === MESSAGE_TYPE.OUTGOING)
        )
        .sort((a, b) => a.created_at - b.created_at);

      const firstAt = messages.length ? formatIso(messages[0].created_at) : nowIso;
      const lastAt = messages.length
        ? formatIso(messages[messages.length - 1].created_at)
        : nowIso;

      const convHeader = [
        dash,
        `CONVERSA ${idx + 1} de ${totalConversations}  |  #${conv.id}  |  ${conv.inboxId ? `Inbox ${conv.inboxId}` : ''}`,
        `Período     :  ${firstAt}  →  ${lastAt}`,
        `Mensagens   :  ${messages.length}`,
        dash,
        '',
      ].join('\n');

      const convBody = messages
        .map((msg, mIdx) => {
          const seq = String(mIdx + 1).padStart(3, '0');
          const ts = formatIso(msg.created_at);
          const role =
            msg.message_type === MESSAGE_TYPE.INCOMING ? 'CLIENTE' : 'AGENTE';
          const senderName =
            msg.message_type === MESSAGE_TYPE.INCOMING
              ? contactName
              : msg.sender?.name || 'Agente';
          const lines = [`[${seq}] ${ts} | ${role} - ${senderName}`];
          if (msg.content) lines.push(`      ${msg.content}`);
          lines.push(...formatAttachments(msg.attachments));
          return lines.join('\n');
        })
        .join('\n\n');

      return convHeader + (convBody || '      (sem mensagens)');
    })
    .join('\n\n');

  const footer = [
    '',
    sep,
    `Total de conversas : ${totalConversations}`,
    `Exportado em       : ${nowIso}`,
    sep,
  ].join('\n');

  downloadTextFile(
    `transcript-${contactName.replace(/\s+/g, '_')}-todas.txt`,
    fileHeader + body + footer
  );
  closeBulkModal();
};

// ─── Send bulk transcript by email ────────────────────────────────────────
const sendBulkTranscript = async () => {
  isSubmitting.value = true;
  try {
    await ContactAPI.sendBulkTranscript(contactId.value, selectedEmailAddress.value);
    useAlert(t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.SEND_SUCCESS'));
    closeBulkModal();
  } catch {
    useAlert(t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.SEND_ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div>
    <!-- Bulk transcript trigger -->
    <div
      v-if="!isFetching && contactConversations.length > 0"
      class="flex justify-end px-6 pt-4 pb-1"
    >
      <Button
        size="xs"
        slate
        faded
        :label="t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.BUTTON')"
        icon="i-ph-file-text"
        @click="openBulkModal"
      />
    </div>

    <!-- Conversations list -->
    <div
      v-if="isFetching"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <div
      v-else-if="contactConversations.length > 0"
      class="px-6 py-4 divide-y divide-n-strong [&>*:hover]:!border-y-transparent [&>*:hover+*]:!border-t-transparent"
    >
      <ConversationCard
        v-for="conversation in contactConversations"
        :key="conversation.id"
        :conversation="conversation"
        :contact="contactsById(conversation.meta.sender.id)"
        :state-inbox="stateInbox(conversation.inboxId)"
        :account-labels="accountLabelsValue"
        class="rounded-none hover:rounded-xl hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3"
      />
    </div>
    <p v-else class="px-6 py-10 text-sm leading-6 text-center text-n-slate-11">
      {{ t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.EMPTY_STATE') }}
    </p>

    <!-- Bulk transcript modal -->
    <woot-modal v-if="showBulkModal" v-model:show="showBulkModal" :on-close="closeBulkModal">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.TITLE')"
          :header-content="t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.DESC', { count: contactConversations.length })"
        />
        <form class="w-full" @submit.prevent="sendBulkTranscript">
          <div class="w-full">
            <div
              v-if="contact?.email"
              class="flex items-center gap-2"
            >
              <input
                id="bulk-contact"
                v-model="selectedType"
                type="radio"
                name="bulkSelectedType"
                value="contact"
              />
              <label for="bulk-contact">
                {{ t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.SEND_TO_CONTACT') }}
                <span class="text-n-slate-10 text-xs">({{ contact.email }})</span>
              </label>
            </div>
            <div class="flex items-center gap-2">
              <input
                id="bulk-other"
                v-model="selectedType"
                type="radio"
                name="bulkSelectedType"
                value="other"
              />
              <label for="bulk-other">
                {{ t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.SEND_TO_OTHER') }}
              </label>
            </div>
            <div v-if="sentToOtherEmail" class="w-[50%] mt-1">
              <label :class="{ error: v$.customEmail.$error }">
                <input
                  v-model="customEmail"
                  type="text"
                  :placeholder="t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.EMAIL_PLACEHOLDER')"
                  @input="v$.customEmail.$touch"
                />
                <span v-if="v$.customEmail.$error" class="message">
                  {{ t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.EMAIL_ERROR') }}
                </span>
              </label>
            </div>
          </div>
          <div class="flex flex-row justify-between w-full gap-2 px-0 py-2">
            <Button
              faded
              slate
              type="button"
              :label="t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.DOWNLOAD')"
              icon="i-ph-download-simple"
              @click.prevent="downloadBulkTranscript"
            />
            <div class="flex gap-2">
              <Button
                faded
                slate
                type="reset"
                :label="t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.CANCEL')"
                @click.prevent="closeBulkModal"
              />
              <Button
                type="submit"
                :label="t('CONTACTS_LAYOUT.SIDEBAR.HISTORY.BULK_TRANSCRIPT.SEND')"
                :disabled="!isFormValid"
                :is-loading="isSubmitting"
              />
            </div>
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>
