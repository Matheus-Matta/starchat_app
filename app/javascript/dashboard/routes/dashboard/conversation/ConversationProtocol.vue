<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  protocolId: {
    type: [Number, String],
    default: null,
  },
  protocolCode: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const store = useStore();
const alert = useAlert();

// ─── State local ────────────────────────────────────────────────────────────
const editMode = ref(false);
const editReason = ref('');
const editDescription = ref('');
const editProblem = ref('');
const newComment = ref('');
const newCommentPrivate = ref(false);
const selectedFiles = ref([]);
const fileInputRef = ref(null);
const showCloseConfirm = ref(false);
const showDeleteCommentConfirm = ref(false);
const commentIdToDelete = ref(null);

// ─── Getters ─────────────────────────────────────────────────────────────────
const uiFlags = useMapGetter('protocols/getUIFlags');
const commentUiFlags = useMapGetter('protocolComments/getUIFlags');
const getProtocolById = useMapGetter('protocols/getProtocolById');
const getCommentsByProtocol = useMapGetter(
  'protocolComments/getCommentsByProtocol'
);

const protocol = computed(() =>
  props.protocolId ? getProtocolById.value(props.protocolId) : null
);
const comments = computed(() =>
  props.protocolId ? getCommentsByProtocol.value(props.protocolId) : []
);

const isOpen = computed(() => protocol.value?.status === 'open');
const isClosed = computed(() => protocol.value?.status === 'closed');
const statusLabel = computed(() => {
  const s = protocol.value?.status;
  if (!s) return '';
  return t(`PROTOCOLS.STATUS.${s.toUpperCase()}`);
});
const statusClass = computed(() => ({
  'bg-g-8 text-g-1': isOpen.value,
  'bg-n-400 text-n-1': isClosed.value,
  'bg-r-8 text-r-1': protocol.value?.status === 'archived',
}));

// ─── Inicializa campos de edição quando protocol muda ────────────────────────
watch(
  protocol,
  val => {
    if (val) {
      editReason.value = val.reason ?? '';
      editDescription.value = val.description ?? '';
      editProblem.value = val.problem ?? '';
    }
  },
  { immediate: true }
);

// ─── Carrega dados ao montar ─────────────────────────────────────────────────
onMounted(async () => {
  if (props.protocolId) {
    await store.dispatch('protocols/show', props.protocolId);
    await store.dispatch('protocolComments/get', props.protocolId);
  }
});

// Also refresh when protocolId changes (e.g., different conversation)
watch(
  () => props.protocolId,
  async newId => {
    if (newId) {
      await store.dispatch('protocols/show', newId);
      await store.dispatch('protocolComments/get', newId);
    }
  }
);

// ─── Ações ───────────────────────────────────────────────────────────────────
const onCopyCode = async () => {
  const code = protocol.value?.code || props.protocolCode;
  if (!code) return;
  await copyTextToClipboard(code);
  alert(t('PROTOCOLS.COPY_SUCCESS', { code }));
};

const onSaveEdit = async () => {
  if (!props.protocolId) return;
  await store.dispatch('protocols/update', {
    id: props.protocolId,
    reason: editReason.value,
    description: editDescription.value,
    problem: editProblem.value,
  });
  editMode.value = false;
  alert(t('PROTOCOLS.SAVE_SUCCESS'));
};

const onClose = () => {
  if (!props.protocolId) return;
  showCloseConfirm.value = true;
};

const confirmClose = async () => {
  showCloseConfirm.value = false;
  await store.dispatch('protocols/close', props.protocolId);
  alert(t('PROTOCOLS.CLOSE_SUCCESS'));
};

const onReopen = async () => {
  if (!props.protocolId) return;
  await store.dispatch('protocols/reopen', props.protocolId);
  alert(t('PROTOCOLS.REOPEN_SUCCESS'));
};

const onFileSelect = e => {
  selectedFiles.value = Array.from(e.target.files);
};

const clearFileInput = () => {
  selectedFiles.value = [];
  if (fileInputRef.value) fileInputRef.value.value = '';
};

const onAddComment = async () => {
  if (!newComment.value.trim()) return;
  await store.dispatch('protocolComments/create', {
    protocolId: props.protocolId,
    data: {
      content: newComment.value.trim(),
      is_private: newCommentPrivate.value,
    },
    files: selectedFiles.value,
  });
  newComment.value = '';
  newCommentPrivate.value = false;
  clearFileInput();
  alert(t('PROTOCOLS.COMMENTS.CREATE_SUCCESS'));
};

const onDeleteComment = commentId => {
  commentIdToDelete.value = commentId;
  showDeleteCommentConfirm.value = true;
};

const confirmDeleteComment = async () => {
  showDeleteCommentConfirm.value = false;
  await store.dispatch('protocolComments/delete', {
    protocolId: props.protocolId,
    commentId: commentIdToDelete.value,
  });
  commentIdToDelete.value = null;
  alert(t('PROTOCOLS.COMMENTS.DELETE_SUCCESS'));
};

const formatDate = iso => {
  if (!iso) return '';
  return new Date(iso).toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};
</script>

<template>
  <div class="flex flex-col gap-3 px-3 pb-4">
    <!-- ─── Estado vazio ──────────────────────────────────────────────── -->
    <div
      v-if="!protocolId && !protocolCode"
      class="flex flex-col items-center justify-center py-6 gap-2 text-center"
    >
      <div
        class="size-10 rounded-full bg-n-slate-3 flex items-center justify-center"
      >
        <span class="i-lucide-clipboard-x size-5 text-n-slate-8" />
      </div>
      <p class="text-xs text-n-slate-9 font-medium">
        {{ $t('PROTOCOLS.EMPTY_STATE') }}
      </p>
    </div>

    <!-- ─── Protocolo vinculado ───────────────────────────────────────── -->
    <template v-else>
      <!-- Card do protocolo -->
      <div
        class="rounded-xl border border-n-weak bg-n-solid-2 dark:bg-n-solid-2 overflow-hidden shadow-sm"
      >
        <!-- Topo: código + status + ações -->
        <div
          class="flex items-center justify-between gap-2 px-3 py-2.5 border-b border-n-weak"
        >
          <!-- Código -->
          <div class="flex items-center gap-2 min-w-0">
            <div
              class="size-6 rounded-lg bg-n-brand/10 flex items-center justify-center flex-shrink-0"
            >
              <span class="i-lucide-hash size-3.5 text-n-brand" />
            </div>
            <span
              class="font-mono font-bold text-sm text-n-slate-12 select-all truncate"
            >
              {{ protocol?.code || protocolCode }}
            </span>
            <button
              v-tooltip="$t('PROTOCOLS.ACTIONS.COPY_CODE')"
              class="size-5 rounded flex items-center justify-center text-n-slate-8 hover:text-n-brand hover:bg-n-brand/10 transition-all flex-shrink-0"
              @click="onCopyCode"
            >
              <span class="i-lucide-copy size-3" />
            </button>
          </div>

          <!-- Badge status -->
          <span
            v-if="protocol?.status"
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold tracking-wide flex-shrink-0"
            :class="{
              'bg-g-50 text-g-700 border border-g-200 dark:bg-g-900/20 dark:text-g-400 dark:border-g-800':
                isOpen,
              'bg-n-slate-3 text-n-slate-10 border border-n-weak': isClosed,
              'bg-r-50 text-r-700 border border-r-200 dark:bg-r-900/20 dark:text-r-400 dark:border-r-800':
                protocol?.status === 'archived',
            }"
          >
            <span
              class="size-1.5 rounded-full"
              :class="{
                'bg-g-500': isOpen,
                'bg-n-slate-8': isClosed,
                'bg-r-500': protocol?.status === 'archived',
              }"
            />
            {{ statusLabel }}
          </span>
        </div>

        <!-- Ações rápidas -->
        <div
          class="flex items-center gap-1 px-3 py-2 bg-n-solid-3 dark:bg-n-solid-3"
        >
          <button
            v-if="isOpen"
            class="flex items-center gap-1 text-[11px] font-semibold text-r-600 hover:text-r-700 hover:bg-r-50 dark:hover:bg-r-900/20 border border-r-200 dark:border-r-800/40 rounded-lg px-2.5 py-1 transition-all disabled:opacity-40"
            :disabled="uiFlags?.isClosing"
            @click="onClose"
          >
            <span class="i-lucide-lock size-3" />
            {{ $t('PROTOCOLS.ACTIONS.CLOSE') }}
          </button>
          <button
            v-else-if="isClosed"
            class="flex items-center gap-1 text-[11px] font-semibold text-g-600 hover:text-g-700 hover:bg-g-50 dark:hover:bg-g-900/20 border border-g-200 dark:border-g-800/40 rounded-lg px-2.5 py-1 transition-all disabled:opacity-40"
            :disabled="uiFlags?.isReopening"
            @click="onReopen"
          >
            <span class="i-lucide-lock-open size-3" />
            {{ $t('PROTOCOLS.ACTIONS.REOPEN') }}
          </button>
          <div class="flex-1" />
          <button
            v-tooltip="$t('PROTOCOLS.ACTIONS.EDIT')"
            class="size-6 rounded-lg flex items-center justify-center transition-all"
            :class="
              editMode
                ? 'bg-n-brand text-white shadow-sm'
                : 'text-n-slate-9 hover:text-n-brand hover:bg-n-brand/10'
            "
            @click="editMode = !editMode"
          >
            <span class="i-lucide-pencil size-3.5" />
          </button>
        </div>
      </div>

      <!-- ─── Campos informativos ────────────────────────────────────── -->
      <template v-if="!editMode && protocol">
        <div
          v-if="protocol.reason || protocol.problem || protocol.description"
          class="flex flex-col divide-y divide-n-weak rounded-xl border border-n-weak overflow-hidden bg-white dark:bg-n-solid-2 shadow-sm"
        >
          <div v-if="protocol.reason" class="px-3 py-2.5">
            <p
              class="text-[10px] font-bold text-n-slate-9 uppercase tracking-wider mb-1"
            >
              {{ $t('PROTOCOLS.FORM.REASON.LABEL') }}
            </p>
            <p class="text-xs text-n-slate-12 font-medium leading-relaxed">
              {{ protocol.reason }}
            </p>
          </div>
          <div v-if="protocol.problem" class="px-3 py-2.5">
            <p
              class="text-[10px] font-bold text-n-slate-9 uppercase tracking-wider mb-1"
            >
              {{ $t('PROTOCOLS.FORM.PROBLEM.LABEL') }}
            </p>
            <p class="text-xs text-n-slate-12 font-medium leading-relaxed">
              {{ protocol.problem }}
            </p>
          </div>
          <div v-if="protocol.description" class="px-3 py-2.5">
            <p
              class="text-[10px] font-bold text-n-slate-9 uppercase tracking-wider mb-1"
            >
              {{ $t('PROTOCOLS.FORM.DESCRIPTION.LABEL') }}
            </p>
            <p
              class="text-xs text-n-slate-12 font-medium leading-relaxed whitespace-pre-wrap"
            >
              {{ protocol.description }}
            </p>
          </div>
        </div>
        <div
          v-if="protocol.conversations_count > 1"
          class="flex items-center gap-1.5 px-1"
        >
          <span class="i-lucide-messages-square size-3 text-n-slate-9" />
          <span class="text-[11px] text-n-slate-9 font-medium">
            {{ $t('PROTOCOLS.TABLE.CONVERSATIONS') }}:
            {{ protocol.conversations_count }}
          </span>
        </div>
      </template>

      <!-- ─── Formulário de edição ───────────────────────────────────── -->
      <div
        v-if="editMode"
        class="flex flex-col gap-3 rounded-xl border border-n-brand/30 bg-n-brand/5 dark:bg-n-brand/5 p-3 shadow-sm"
      >
        <div class="flex flex-col gap-1">
          <label
            class="text-[10px] font-bold text-n-slate-10 uppercase tracking-wider"
          >
            {{ $t('PROTOCOLS.FORM.REASON.LABEL') }}
          </label>
          <input
            v-model="editReason"
            type="text"
            class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-xs text-n-slate-12 font-medium shadow-sm transition-all focus:border-n-brand focus:ring-2 focus:ring-n-brand/10 outline-none placeholder:text-n-slate-8"
            :placeholder="$t('PROTOCOLS.FORM.REASON.PLACEHOLDER')"
            maxlength="500"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label
            class="text-[10px] font-bold text-n-slate-10 uppercase tracking-wider"
          >
            {{ $t('PROTOCOLS.FORM.PROBLEM.LABEL') }}
          </label>
          <input
            v-model="editProblem"
            type="text"
            class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-xs text-n-slate-12 font-medium shadow-sm transition-all focus:border-n-brand focus:ring-2 focus:ring-n-brand/10 outline-none placeholder:text-n-slate-8"
            :placeholder="$t('PROTOCOLS.FORM.PROBLEM.PLACEHOLDER')"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label
            class="text-[10px] font-bold text-n-slate-10 uppercase tracking-wider"
          >
            {{ $t('PROTOCOLS.FORM.DESCRIPTION.LABEL') }}
          </label>
          <textarea
            v-model="editDescription"
            rows="3"
            class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-xs text-n-slate-12 font-medium shadow-sm transition-all focus:border-n-brand focus:ring-2 focus:ring-n-brand/10 outline-none resize-none placeholder:text-n-slate-8"
            :placeholder="$t('PROTOCOLS.FORM.DESCRIPTION.PLACEHOLDER')"
          />
        </div>
        <div class="flex justify-end gap-2">
          <button
            class="text-[11px] font-semibold text-n-slate-10 hover:text-n-slate-12 px-3 py-1.5 rounded-lg hover:bg-n-slate-3 transition-all"
            @click="editMode = false"
          >
            {{ $t('PROTOCOLS.FORM.CANCEL') }}
          </button>
          <button
            class="flex items-center gap-1.5 text-[11px] font-bold text-white bg-n-brand hover:bg-n-brand/90 rounded-lg px-3 py-1.5 shadow-sm transition-all disabled:opacity-40"
            :disabled="uiFlags?.isUpdating"
            @click="onSaveEdit"
          >
            <span class="i-lucide-check size-3.5" />
            {{ $t('PROTOCOLS.FORM.SAVE_BTN') }}
          </button>
        </div>
      </div>

      <!-- ─── Seção de Anotações / Comentários ──────────────────────── -->
      <div class="flex flex-col gap-2 pt-1">
        <!-- Header Anotações -->
        <div class="flex items-center gap-2">
          <span class="i-lucide-notebook-pen size-3.5 text-n-slate-9" />
          <span
            class="text-[11px] font-bold text-n-slate-10 uppercase tracking-wider"
          >
            {{ $t('PROTOCOLS.COMMENTS.TITLE') }}
          </span>
          <span
            v-if="comments.length"
            class="inline-flex items-center justify-center size-4 rounded-full bg-n-slate-3 text-[9px] font-black text-n-slate-10"
          >
            {{ comments.length }}
          </span>
        </div>

        <!-- Loading -->
        <div
          v-if="commentUiFlags?.isFetching"
          class="flex items-center gap-2 py-2 px-1"
        >
          <span
            class="i-lucide-loader-2 size-3.5 text-n-slate-8 animate-spin"
          />
          <span class="text-xs text-n-slate-9">{{
            $t('PROTOCOLS.COMMENTS.LOADING')
          }}</span>
        </div>

        <!-- Lista vazia -->
        <div
          v-else-if="!comments.length"
          class="text-xs text-n-slate-9 italic text-center py-3"
        >
          {{ $t('PROTOCOLS.COMMENTS.EMPTY') }}
        </div>

        <!-- Lista de comentários -->
        <div v-else class="flex flex-col gap-2">
          <div
            v-for="comment in comments"
            :key="comment.id"
            class="rounded-lg border p-2.5 flex flex-col gap-1.5"
            :class="
              comment.is_private
                ? 'bg-y-50 border-y-200 dark:bg-y-900/10 dark:border-y-800/40'
                : 'bg-white border-n-weak dark:bg-n-solid-3'
            "
          >
            <!-- Meta -->
            <div class="flex items-center justify-between gap-1">
              <div class="flex items-center gap-1.5 min-w-0">
                <span class="text-[11px] font-bold text-n-slate-11 truncate">
                  {{ comment.user?.name || 'Agente' }}
                </span>
                <span
                  class="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded-full text-[9px] font-bold uppercase tracking-wide flex-shrink-0"
                  :class="
                    comment.is_private
                      ? 'bg-y-100 text-y-700 dark:bg-y-900/30 dark:text-y-400'
                      : 'bg-n-slate-3 text-n-slate-9'
                  "
                >
                  <span
                    v-if="comment.is_private"
                    class="i-lucide-lock size-2"
                  />
                  {{
                    comment.is_private
                      ? $t('PROTOCOLS.COMMENTS.BADGE_PRIVATE')
                      : $t('PROTOCOLS.COMMENTS.BADGE_PUBLIC')
                  }}
                </span>
              </div>
              <div class="flex items-center gap-1 flex-shrink-0">
                <span class="text-[10px] text-n-slate-8 font-medium">
                  {{ formatDate(comment.created_at) }}
                </span>
                <button
                  v-tooltip="$t('PROTOCOLS.COMMENTS.DELETE_CONFIRM_TITLE')"
                  class="size-5 rounded flex items-center justify-center text-n-slate-7 hover:text-r-500 hover:bg-r-50 dark:hover:bg-r-900/20 transition-all"
                  @click="onDeleteComment(comment.id)"
                >
                  <span class="i-lucide-trash-2 size-3" />
                </button>
              </div>
            </div>

            <!-- Conteúdo -->
            <p
              class="text-xs text-n-slate-12 leading-relaxed whitespace-pre-wrap"
            >
              {{ comment.content }}
            </p>

            <!-- Anexos -->
            <div
              v-if="comment.files?.length"
              class="flex flex-wrap gap-1 pt-0.5 border-t border-n-weak/50"
            >
              <a
                v-for="file in comment.files"
                :key="file.id"
                :href="file.url"
                target="_blank"
                rel="noopener noreferrer"
                class="flex items-center gap-1 text-[10px] font-semibold text-n-brand hover:text-n-brand/80 bg-n-brand/5 hover:bg-n-brand/10 rounded px-1.5 py-0.5 transition-all"
              >
                <span class="i-lucide-paperclip size-2.5" />
                {{ file.filename }}
              </a>
            </div>
          </div>
        </div>

        <!-- ─── Formulário de nova anotação ─────────────────────────── -->
        <div
          class="flex flex-col gap-2 rounded-xl border border-n-weak bg-white dark:bg-n-solid-3 p-2.5 shadow-sm mt-1"
        >
          <textarea
            v-model="newComment"
            rows="2"
            class="w-full text-xs text-n-slate-12 font-medium placeholder:text-n-slate-8 bg-transparent outline-none resize-none leading-relaxed"
            :placeholder="$t('PROTOCOLS.COMMENTS.NEW_PLACEHOLDER')"
          />

          <!-- Arquivos selecionados -->
          <div v-if="selectedFiles.length" class="flex flex-wrap gap-1">
            <span
              v-for="(file, idx) in selectedFiles"
              :key="idx"
              class="flex items-center gap-1 text-[10px] font-semibold bg-n-slate-3 text-n-slate-11 rounded px-1.5 py-0.5"
            >
              <span class="i-lucide-file size-2.5 text-n-slate-9" />
              {{ file.name }}
              <button
                class="text-n-slate-8 hover:text-r-500 transition-colors ml-0.5"
                @click="selectedFiles.splice(idx, 1)"
              >
                <span class="i-lucide-x size-2.5" />
              </button>
            </span>
          </div>

          <!-- Barra inferior do formulário -->
          <div class="flex items-center gap-2 pt-1.5 border-t border-n-weak">
            <!-- Privado -->
            <label
              class="flex items-center gap-1 cursor-pointer select-none group"
            >
              <div
                class="size-3.5 rounded border flex items-center justify-center transition-all flex-shrink-0"
                :class="
                  newCommentPrivate
                    ? 'bg-y-500 border-y-500'
                    : 'border-n-weak group-hover:border-n-slate-9'
                "
              >
                <span
                  v-if="newCommentPrivate"
                  class="i-lucide-check size-2.5 text-white"
                />
              </div>
              <input
                v-model="newCommentPrivate"
                type="checkbox"
                class="sr-only"
              />
              <span class="text-[10px] font-semibold text-n-slate-9">
                {{ $t('PROTOCOLS.COMMENTS.PRIVATE_LABEL') }}
              </span>
            </label>

            <div class="flex-1" />

            <!-- Input de arquivo oculto -->
            <input
              ref="fileInputRef"
              type="file"
              multiple
              class="hidden"
              @change="onFileSelect"
            />

            <!-- Botão anexar -->
            <button
              v-tooltip="$t('PROTOCOLS.COMMENTS.ATTACH_FILE')"
              class="size-6 rounded-lg flex items-center justify-center text-n-slate-8 hover:text-n-brand hover:bg-n-brand/10 transition-all"
              @click="fileInputRef?.click()"
            >
              <span class="i-lucide-paperclip size-3.5" />
            </button>

            <!-- Botão enviar -->
            <button
              class="flex items-center gap-1 text-[11px] font-bold text-white bg-n-brand hover:bg-n-brand/90 rounded-lg px-2.5 py-1 transition-all disabled:opacity-40 shadow-sm"
              :disabled="!newComment.trim() || commentUiFlags?.isCreating"
              @click="onAddComment"
            >
              <span class="i-lucide-send-horizontal size-3" />
              {{ $t('PROTOCOLS.COMMENTS.SEND') }}
            </button>
          </div>
        </div>
      </div>
    </template>
  </div>

  <!-- Modal confirmação: fechar protocolo -->
  <woot-confirm-delete-modal
    v-if="showCloseConfirm"
    v-model:show="showCloseConfirm"
    :title="$t('PROTOCOLS.CLOSE_CONFIRM_TITLE')"
    :message="
      $t('PROTOCOLS.CLOSE_CONFIRM', { code: protocol?.code || protocolCode })
    "
    :confirm-text="$t('PROTOCOLS.ACTIONS.CLOSE')"
    :reject-text="$t('PROTOCOLS.ACTIONS.CANCEL')"
    @on-confirm="confirmClose"
  />

  <!-- Modal confirmação: excluir comentário -->
  <woot-confirm-delete-modal
    v-if="showDeleteCommentConfirm"
    v-model:show="showDeleteCommentConfirm"
    :title="$t('PROTOCOLS.COMMENTS.DELETE_CONFIRM_TITLE')"
    :message="$t('PROTOCOLS.COMMENTS.DELETE_CONFIRM')"
    :confirm-text="$t('PROTOCOLS.COMMENTS.DELETE_ACTION')"
    :reject-text="$t('PROTOCOLS.ACTIONS.CANCEL')"
    @on-confirm="confirmDeleteComment"
  />
</template>
