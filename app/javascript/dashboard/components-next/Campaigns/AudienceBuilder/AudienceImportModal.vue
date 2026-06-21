<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { read, utils } from 'xlsx';
import { useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['add', 'close']);
const store = useStore();
const { t } = useI18n();

const i18n = key => t(`CAMPAIGN.AUDIENCE_BUILDER.IMPORT_MODAL.${key}`);

const fileInput = ref(null);
const fileName = ref('');
const columns = ref([]);
const rows = ref([]);
const columnType = ref('identifier');
const isMatching = ref(false);
const matchResult = ref(null);
const parseError = ref('');

const COLUMN_TYPES = [
  { value: 'identifier', pattern: /^identifier$/i },
  { value: 'id', pattern: /^id$/i },
  { value: 'phone', pattern: /phone|telefone|celular|whatsapp|fone/i },
  { value: 'email', pattern: /email|e-mail|mail/i },
];

const hasFile = computed(() => rows.value.length > 0);

const detectedColumn = computed(() => {
  const def = COLUMN_TYPES.find(ct => ct.value === columnType.value);
  if (!def) return null;
  return columns.value.find(c => def.pattern.test(c.trim())) ?? null;
});

const selectedValues = computed(() => {
  if (!detectedColumn.value || !rows.value.length) return [];
  return rows.value
    .map(row => String(row[detectedColumn.value] ?? '').trim())
    .filter(Boolean);
});

const columnNotFound = computed(() => hasFile.value && !detectedColumn.value);

const parseFile = async file => {
  parseError.value = '';
  matchResult.value = null;
  try {
    const buffer = await file.arrayBuffer();
    const workbook = read(buffer, { type: 'array' });
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const data = utils.sheet_to_json(sheet, { defval: '' });

    if (!data.length) {
      parseError.value = 'Planilha vazia ou sem dados reconhecidos.';
      return;
    }

    columns.value = Object.keys(data[0]);
    rows.value = data;
    fileName.value = file.name;

    const best = COLUMN_TYPES.find(ct =>
      columns.value.some(c => ct.pattern.test(c.trim()))
    );
    if (best) columnType.value = best.value;
  } catch {
    parseError.value = i18n('PARSE_ERROR');
  }
};

// Reset result when type changes
watch(columnType, () => {
  matchResult.value = null;
});

const onFileChange = e => {
  const f = e.target.files[0];
  if (f) parseFile(f);
};
const onDrop = e => {
  const f = e.dataTransfer.files[0];
  if (f) parseFile(f);
};

const matchContacts = async () => {
  isMatching.value = true;
  matchResult.value = null;
  const values = selectedValues.value;
  const payload =
    columnType.value === 'id'
      ? { ids: values }
      : columnType.value === 'identifier'
        ? { identifiers: values }
        : columnType.value === 'phone'
          ? { phones: values }
          : { emails: values };
  const data = await store.dispatch('campaigns/matchContacts', payload);
  matchResult.value = data;
  isMatching.value = false;
};

const addToAudience = () => {
  if (!matchResult.value?.contacts?.length) return;
  emit('add', {
    type: 'ContactList',
    contact_ids: matchResult.value.contacts.map(c => c.id),
    label: t('CAMPAIGN.AUDIENCE_BUILDER.IMPORT_MODAL.SEGMENT_LABEL', {
      count: matchResult.value.contacts.length,
    }),
  });
  reset();
};

const reset = () => {
  if (fileInput.value) fileInput.value.value = '';
  fileName.value = '';
  columns.value = [];
  rows.value = [];
  columnType.value = 'identifier';
  matchResult.value = null;
  parseError.value = '';
};
</script>

<template>
  <div class="flex flex-col gap-5">
    <!-- Drop zone -->
    <div
      class="border-2 border-dashed rounded-xl p-8 flex flex-col items-center gap-3 cursor-pointer hover:border-n-brand transition-colors"
      :class="
        hasFile ? 'border-n-teal-7 bg-n-teal-2' : 'border-n-weak bg-n-alpha-1'
      "
      @dragover.prevent
      @drop.prevent="onDrop"
      @click="fileInput?.click()"
    >
      <i
        class="i-lucide-file-spreadsheet w-8 h-8"
        :class="hasFile ? 'text-n-teal-11' : 'text-n-slate-9'"
      />
      <div class="text-center">
        <p class="text-sm font-medium text-n-slate-12">
          {{ hasFile ? fileName : i18n('DROPZONE_IDLE') }}
        </p>
        <p class="text-xs text-n-slate-10 mt-0.5">
          {{
            hasFile
              ? i18n('DROPZONE_LOADED', { count: rows.length })
              : i18n('DROPZONE_HINT')
          }}
        </p>
      </div>
      <input
        ref="fileInput"
        type="file"
        accept=".csv,.xlsx,.xls"
        class="hidden"
        @change="onFileChange"
      />
    </div>

    <p v-if="parseError" class="text-xs text-n-ruby-11">{{ parseError }}</p>

    <!-- Field selector + preview -->
    <div v-if="hasFile" class="flex flex-col gap-4">
      <div class="flex flex-col gap-1">
        <label
          class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide"
        >
          {{ i18n('FIELD_LABEL') }}
        </label>
        <select
          v-model="columnType"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        >
          <option v-for="ct in COLUMN_TYPES" :key="ct.value" :value="ct.value">
            {{ i18n(`FIELD_TYPES.${ct.value.toUpperCase()}`) }}
          </option>
        </select>
        <p v-if="columnNotFound" class="text-xs text-n-ruby-11">
          {{
            i18n('COLUMN_NOT_FOUND', {
              type: columnType,
              columns: columns.join(', '),
            })
          }}
        </p>
        <p v-else-if="detectedColumn" class="text-xs text-n-slate-10">
          {{
            i18n('COLUMN_DETECTED', {
              column: detectedColumn,
              count: selectedValues.length,
            })
          }}
        </p>
      </div>

      <Button
        :label="i18n('SEARCH_BUTTON')"
        icon="i-lucide-search"
        size="sm"
        :is-loading="isMatching"
        :disabled="!selectedValues.length || isMatching"
        @click="matchContacts"
      />
    </div>

    <!-- Match result -->
    <div v-if="matchResult" class="flex flex-col gap-3">
      <div class="flex gap-3">
        <div
          class="flex-1 bg-n-teal-2 rounded-lg px-4 py-3 flex flex-col gap-0.5"
        >
          <span class="text-lg font-bold text-n-teal-11">{{
            matchResult.matched
          }}</span>
          <span class="text-xs text-n-teal-10">
            {{ i18n('MATCHED_LABEL') }}
          </span>
        </div>
        <div
          class="flex-1 bg-n-alpha-2 rounded-lg px-4 py-3 flex flex-col gap-0.5"
        >
          <span class="text-lg font-bold text-n-slate-10">{{
            matchResult.unmatched
          }}</span>
          <span class="text-xs text-n-slate-10">
            {{ i18n('UNMATCHED_LABEL') }}
          </span>
        </div>
      </div>

      <div
        v-if="matchResult.contacts.length"
        class="flex flex-col gap-1.5 max-h-40 overflow-y-auto"
      >
        <div
          v-for="contact in matchResult.contacts.slice(0, 10)"
          :key="contact.id"
          class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-alpha-2 text-sm"
        >
          <i class="i-lucide-user w-3.5 h-3.5 text-n-slate-9 shrink-0" />
          <span class="font-medium text-n-slate-12 truncate">{{
            contact.name
          }}</span>
          <span class="text-n-slate-10 truncate text-xs">
            {{ contact.identifier || contact.phone_number || contact.email }}
          </span>
        </div>
        <p
          v-if="matchResult.contacts.length > 10"
          class="text-xs text-n-slate-10 text-center"
        >
          +{{ matchResult.contacts.length - 10 }} mais
        </p>
      </div>

      <div class="flex gap-2 pt-1">
        <Button
          v-if="matchResult.matched > 0"
          :label="i18n('ADD_BUTTON', { count: matchResult.matched })"
          icon="i-lucide-plus"
          size="sm"
          @click="addToAudience"
        />
        <Button
          :label="i18n('NEW_IMPORT')"
          variant="faded"
          color="slate"
          size="sm"
          @click="reset"
        />
      </div>
    </div>
  </div>
</template>
