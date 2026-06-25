<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { downloadTextFile } from 'dashboard/helper/downloadHelper';
import ContactAPI from 'dashboard/api/contacts';

export default {
  components: {
    NextButton,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    currentChat: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['cancel', 'update:show'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      email: '',
      selectedType: '',
      scope: 'current',
      isSubmitting: false,
      isFetchingAll: false,
    };
  },
  validations: {
    email: {
      required,
      email,
      minLength: minLength(4),
    },
  },
  computed: {
    localShow: {
      get() {
        return this.show;
      },
      set(value) {
        this.$emit('update:show', value);
      },
    },
    isBulk() {
      return this.scope === 'all';
    },
    modalTitle() {
      return this.isBulk
        ? this.$t('EMAIL_TRANSCRIPT.TITLE_ALL')
        : this.$t('EMAIL_TRANSCRIPT.TITLE');
    },
    modalDesc() {
      return this.isBulk
        ? this.$t('EMAIL_TRANSCRIPT.DESC_ALL')
        : this.$t('EMAIL_TRANSCRIPT.DESC');
    },
    sentToOtherEmailAddress() {
      return this.selectedType === 'other_email_address';
    },
    isFormValid() {
      if (this.selectedType) {
        if (this.sentToOtherEmailAddress) {
          return !!this.email && !this.v$.email.$error;
        }
        return true;
      }
      return false;
    },
    selectedEmailAddress() {
      const { meta } = this.currentChat;
      switch (this.selectedType) {
        case 'contact':
          return meta.sender.email;
        case 'assignee':
          return meta.assignee?.email;
        case 'other_email_address':
          return this.email;
        default:
          return '';
      }
    },
    contactId() {
      return this.currentChat?.meta?.sender?.id;
    },
  },
  methods: {
    onCancel() {
      this.$emit('cancel');
    },
    onScopeChange() {
      // Pre-fetch all conversations when switching to bulk scope
      if (
        this.isBulk &&
        this.contactId &&
        this.contactConversations.length === 0
      ) {
        this.$store.dispatch('contactConversations/get', this.contactId);
      }
    },
    formatIso(unixSeconds) {
      return new Date(unixSeconds * 1000)
        .toISOString()
        .replace('Z', this.tzOffset());
    },
    tzOffset() {
      const pad = n => String(Math.abs(n)).padStart(2, '0');
      const offset = -new Date().getTimezoneOffset();
      const sign = offset >= 0 ? '+' : '-';
      return `${sign}${pad(Math.floor(Math.abs(offset) / 60))}:${pad(Math.abs(offset) % 60)}`;
    },
    formatAttachments(attachments) {
      if (!attachments || !attachments.length) return [];
      return attachments.map(att => {
        const typeLabel = (att.file_type || 'file').toUpperCase();
        const url = att.data_url || att.thumb_url || '';
        const ext = att.extension ? `.${att.extension}` : '';
        return `      [${typeLabel}${ext}] ${url}`;
      });
    },

    // Pulls the full contact record (loaded for the contact panel) instead of the
    // lightweight conversation.meta.sender, since that's the only place city/country/
    // company/bio/created_at/last_activity_at are available on the frontend.
    contactDetailsLines() {
      const senderSummary = this.currentChat.meta?.sender || {};
      const contact =
        this.$store.getters['contacts/getContact'](senderSummary.id) ||
        senderSummary;
      const attrs = contact.additional_attributes || {};
      const cityCountry = [attrs.city, attrs.country]
        .filter(Boolean)
        .join(', ');
      const labels = this.$store.getters['contactLabels/getContactLabels'](
        senderSummary.id
      ).join(', ');

      return [
        contact.email ? `Email     :  ${contact.email}` : null,
        contact.phone_number ? `Phone     :  ${contact.phone_number}` : null,
        attrs.company_name ? `Company   :  ${attrs.company_name}` : null,
        cityCountry ? `Location  :  ${cityCountry}` : null,
        attrs.description ? `Bio       :  ${attrs.description}` : null,
        labels ? `Labels    :  ${labels}` : null,
        contact.created_at
          ? `Created   :  ${this.formatIso(contact.created_at)}`
          : null,
        contact.last_activity_at
          ? `Last seen :  ${this.formatIso(contact.last_activity_at)}`
          : null,
      ].filter(line => line !== null);
    },

    // ── Single conversation download (current behavior) ──────────────────
    buildSingleTranscript() {
      const sep = '='.repeat(80);
      const contactName = this.currentChat.meta?.sender?.name || 'Contact';
      const agentName = this.currentChat.meta?.assignee?.name || '';
      const conversationId = this.currentChat.id;
      const inboxName = this.currentChat.inbox_id || '';
      const now = new Date();
      const nowIso = now.toISOString().replace('Z', this.tzOffset());

      const messages = (this.currentChat.messages || [])
        .filter(
          msg =>
            !msg.private &&
            (msg.message_type === MESSAGE_TYPE.INCOMING ||
              msg.message_type === MESSAGE_TYPE.OUTGOING)
        )
        .sort((a, b) => a.created_at - b.created_at);

      const firstAt = messages.length
        ? this.formatIso(messages[0].created_at)
        : nowIso;
      const lastAt = messages.length
        ? this.formatIso(messages[messages.length - 1].created_at)
        : nowIso;

      const header = [
        sep,
        'TRANSCRIPT OF ELECTRONIC COMMUNICATION',
        sep,
        `Reference :  #${conversationId}`,
        `Contact   :  ${contactName}`,
        ...this.contactDetailsLines(),
        agentName ? `Agent     :  ${agentName}` : null,
        inboxName ? `Inbox ID  :  ${inboxName}` : null,
        `Period    :  ${firstAt}  →  ${lastAt}`,
        `Exported  :  ${nowIso}`,
        sep,
        '',
      ]
        .filter(l => l !== null)
        .join('\n');

      const body = messages
        .map((msg, idx) => {
          const seq = String(idx + 1).padStart(3, '0');
          const ts = this.formatIso(msg.created_at);
          const role =
            msg.message_type === MESSAGE_TYPE.INCOMING ? 'CLIENT' : 'AGENT';
          const senderName =
            msg.message_type === MESSAGE_TYPE.INCOMING
              ? contactName
              : msg.sender?.name || agentName || 'Agent';
          const lines = [`[${seq}] ${ts} | ${role} - ${senderName}`];
          if (msg.content) lines.push(`      ${msg.content}`);
          lines.push(...this.formatAttachments(msg.attachments));
          return lines.join('\n');
        })
        .join('\n\n');

      const footer = [
        '',
        sep,
        `Total messages : ${messages.length}`,
        `Exported at    : ${nowIso}`,
        sep,
      ].join('\n');

      return {
        content: header + body + footer,
        filename: `transcript-${conversationId}.txt`,
      };
    },

    async downloadTranscript() {
      if (this.isBulk) {
        this.isFetchingAll = true;
        try {
          const response = await ContactAPI.downloadBulkTranscript(
            this.contactId
          );
          const blob = new Blob([response.data], {
            type: 'text/plain;charset=utf-8',
          });
          const url = window.URL.createObjectURL(blob);
          const link = document.createElement('a');
          const contactName = (
            this.currentChat.meta?.sender?.name || 'contact'
          ).replace(/\s+/g, '_');
          link.href = url;
          link.setAttribute('download', `transcript-${contactName}-todas.txt`);
          document.body.appendChild(link);
          link.click();
          link.remove();
          window.URL.revokeObjectURL(url);
          this.onCancel();
        } catch {
          useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_ERROR'));
        } finally {
          this.isFetchingAll = false;
        }
      } else {
        if (this.contactId) {
          await this.$store.dispatch('contactLabels/get', this.contactId);
        }
        const { content, filename } = this.buildSingleTranscript();
        downloadTextFile(filename, content);
        this.onCancel();
      }
    },

    async onSubmit() {
      this.isSubmitting = true;
      try {
        if (this.isBulk) {
          await ContactAPI.sendBulkTranscript(
            this.contactId,
            this.selectedEmailAddress
          );
        } else {
          await this.$store.dispatch('sendEmailTranscript', {
            email: this.selectedEmailAddress,
            conversationId: this.currentChat.id,
          });
        }
        useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_SUCCESS'));
        this.onCancel();
      } catch (error) {
        const status = error?.response?.status;
        if (status === 402) {
          useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_PAYMENT_REQUIRED'));
        } else {
          useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_ERROR'));
        }
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onCancel">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="modalTitle"
        :header-content="modalDesc"
      />
      <form class="w-full" @submit.prevent="onSubmit">
        <!-- Scope selector -->
        <div class="flex gap-1 p-1 mb-4 rounded-lg bg-n-alpha-2">
          <button
            type="button"
            class="flex-1 px-3 py-1.5 text-sm rounded-md transition-colors"
            :class="
              scope === 'current'
                ? 'bg-white dark:bg-n-solid-3 text-n-slate-12 shadow-sm font-medium'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="scope = 'current'"
          >
            {{ $t('EMAIL_TRANSCRIPT.SCOPE_CURRENT') }}
          </button>
          <button
            type="button"
            class="flex-1 px-3 py-1.5 text-sm rounded-md transition-colors"
            :class="
              scope === 'all'
                ? 'bg-white dark:bg-n-solid-3 text-n-slate-12 shadow-sm font-medium'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="
              scope = 'all';
              onScopeChange();
            "
          >
            {{ $t('EMAIL_TRANSCRIPT.SCOPE_ALL') }}
          </button>
        </div>

        <!-- Destination options -->
        <div class="w-full">
          <div
            v-if="currentChat.meta.sender && currentChat.meta.sender.email"
            class="flex items-center gap-2"
          >
            <input
              id="contact"
              v-model="selectedType"
              type="radio"
              name="selectedType"
              value="contact"
            />
            <label for="contact">{{
              $t('EMAIL_TRANSCRIPT.FORM.SEND_TO_CONTACT')
            }}</label>
          </div>
          <div
            v-if="!isBulk && currentChat.meta.assignee"
            class="flex items-center gap-2"
          >
            <input
              id="assignee"
              v-model="selectedType"
              type="radio"
              name="selectedType"
              value="assignee"
            />
            <label for="assignee">{{
              $t('EMAIL_TRANSCRIPT.FORM.SEND_TO_AGENT')
            }}</label>
          </div>
          <div class="flex items-center gap-2">
            <input
              id="other_email_address"
              v-model="selectedType"
              type="radio"
              name="selectedType"
              value="other_email_address"
            />
            <label for="other_email_address">{{
              $t('EMAIL_TRANSCRIPT.FORM.SEND_TO_OTHER_EMAIL_ADDRESS')
            }}</label>
          </div>
          <div v-if="sentToOtherEmailAddress" class="w-[50%] mt-1">
            <label :class="{ error: v$.email.$error }">
              <input
                v-model="email"
                type="text"
                :placeholder="$t('EMAIL_TRANSCRIPT.FORM.EMAIL.PLACEHOLDER')"
                @input="v$.email.$touch"
              />
              <span v-if="v$.email.$error" class="message">
                {{ $t('EMAIL_TRANSCRIPT.FORM.EMAIL.ERROR') }}
              </span>
            </label>
          </div>
        </div>

        <!-- Actions -->
        <div class="flex flex-row justify-between w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="button"
            :label="$t('EMAIL_TRANSCRIPT.DOWNLOAD_TRANSCRIPT')"
            :is-loading="isFetchingAll"
            @click.prevent="downloadTranscript"
          />
          <div class="flex gap-2">
            <NextButton
              faded
              slate
              type="reset"
              :label="$t('EMAIL_TRANSCRIPT.CANCEL')"
              @click.prevent="onCancel"
            />
            <NextButton
              type="submit"
              :label="$t('EMAIL_TRANSCRIPT.SUBMIT')"
              :disabled="!isFormValid"
              :is-loading="isSubmitting"
            />
          </div>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
