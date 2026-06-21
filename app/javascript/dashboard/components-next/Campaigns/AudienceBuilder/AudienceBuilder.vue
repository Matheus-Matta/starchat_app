<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import CompanyAPI from 'dashboard/api/companies';

import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import AudienceImportModal from './AudienceImportModal.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  hasError: { type: Boolean, default: false },
  message: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const allLabels = useMapGetter('labels/getLabels');
const contactAttributes = useMapGetter('attributes/getContactAttributes');

// Active panel: null | 'label' | 'company' | 'import' | 'attribute'
const activePanel = ref(null);

// Local state for pickers
const selectedLabelIds = ref([]);
const companySearch = ref('');
const companyOptions = ref([]);
const isSearchingCompany = ref(false);
const showImport = ref(false);

// Attribute picker state
const selectedAttributeKey = ref('');
const attributeValue = ref('');

const attributeOptions = computed(() =>
  (contactAttributes.value || []).map(a => ({
    value: a.attributeKey,
    label: a.attributeDisplayName,
    displayType: a.attributeDisplayType,
    values: a.attributeValues || [],
  }))
);

const selectedAttributeDef = computed(() =>
  attributeOptions.value.find(a => a.value === selectedAttributeKey.value) || null
);

const labelOptions = computed(() =>
  (allLabels.value || []).map(l => ({ value: l.id, label: l.title }))
);

// Existing audience segments grouped by type (for display)
const labelSegments = computed(() =>
  props.modelValue.filter(a => a.type === 'Label')
);
const companySegments = computed(() =>
  props.modelValue.filter(a => a.type === 'Company')
);
const importSegments = computed(() =>
  props.modelValue.filter(a => a.type === 'ContactList')
);

const removeSegment = seg => {
  const next = props.modelValue.filter(a => {
    if (a.type !== seg.type) return true;
    if (seg.type === 'Label') return a.id !== seg.id;
    if (seg.type === 'Company') return a.id !== seg.id;
    if (seg.type === 'ContactList') return a.label !== seg.label;
    if (seg.type === 'Attribute') return !(a.key === seg.key && a.value === seg.value);
    return true;
  });
  emit('update:modelValue', next);
};

const addLabels = () => {
  if (!selectedLabelIds.value.length) return;
  const existingIds = new Set(labelSegments.value.map(s => s.id));
  const newItems = selectedLabelIds.value
    .filter(id => !existingIds.has(id))
    .map(id => {
      const label = allLabels.value.find(l => l.id === id);
      return { type: 'Label', id, name: label?.title || `Label #${id}` };
    });
  emit('update:modelValue', [...props.modelValue, ...newItems]);
  selectedLabelIds.value = [];
  activePanel.value = null;
};

const searchCompanies = async query => {
  companySearch.value = query;
  if (!query) { companyOptions.value = []; return; }
  isSearchingCompany.value = true;
  try {
    const res = await CompanyAPI.search(query);
    companyOptions.value = (res.data.payload || []).map(c => ({
      value: c.id,
      label: c.name,
    }));
  } finally {
    isSearchingCompany.value = false;
  }
};

const selectedCompanyId = ref(null);

const addCompany = () => {
  if (!selectedCompanyId.value) return;
  const opt = companyOptions.value.find(o => o.value === selectedCompanyId.value);
  if (!opt) return;
  const alreadyAdded = companySegments.value.some(s => s.id === opt.value);
  if (!alreadyAdded) {
    emit('update:modelValue', [
      ...props.modelValue,
      { type: 'Company', id: opt.value, name: opt.label },
    ]);
  }
  selectedCompanyId.value = null;
  companySearch.value = '';
  companyOptions.value = [];
  activePanel.value = null;
};

const handleImportAdd = segment => {
  emit('update:modelValue', [...props.modelValue, segment]);
  showImport.value = false;
  activePanel.value = null;
};

const addAttribute = () => {
  if (!selectedAttributeKey.value || !attributeValue.value.toString().trim()) return;
  const def = selectedAttributeDef.value;
  if (!def) return;
  const alreadyAdded = props.modelValue.some(
    s => s.type === 'Attribute' && s.key === selectedAttributeKey.value && s.value === attributeValue.value.toString()
  );
  if (!alreadyAdded) {
    emit('update:modelValue', [
      ...props.modelValue,
      {
        type: 'Attribute',
        key: selectedAttributeKey.value,
        value: attributeValue.value.toString(),
        name: `${def.label}: ${attributeValue.value}`,
      },
    ]);
  }
  selectedAttributeKey.value = '';
  attributeValue.value = '';
  activePanel.value = null;
};

const openPanel = panel => {
  activePanel.value = activePanel.value === panel ? null : panel;
  showImport.value = panel === 'import';
};

const segmentIcon = type => {
  if (type === 'Label') return 'i-lucide-tag';
  if (type === 'Company') return 'i-lucide-building-2';
  if (type === 'Attribute') return 'i-lucide-sliders-horizontal';
  return 'i-lucide-upload';
};

const segmentColor = type => {
  if (type === 'Label') return 'bg-n-brand-subtle text-n-brand';
  if (type === 'Company') return 'bg-n-blue-3 text-n-blue-11';
  if (type === 'Attribute') return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-violet-3 text-n-violet-11';
};

const segmentName = seg => {
  if (seg.type === 'ContactList') return seg.label || 'Importação';
  return seg.name || `#${seg.id}`;
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium text-n-slate-12">
      {{ t('CAMPAIGN.AUDIENCE_BUILDER.LABEL') }}
    </label>

    <!-- Current segments display -->
    <div
      class="min-h-[2.5rem] flex flex-wrap gap-2 px-3 py-2 rounded-lg border transition-colors"
      :class="hasError ? 'border-n-ruby-8' : 'border-n-weak'"
    >
      <template v-if="modelValue.length === 0">
        <span class="text-sm text-n-slate-9 self-center">
          {{ t('CAMPAIGN.AUDIENCE_BUILDER.PLACEHOLDER') }}
        </span>
      </template>
      <span
        v-for="seg in modelValue"
        :key="`${seg.type}-${seg.id ?? seg.key ?? seg.label}`"
        class="inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-full"
        :class="segmentColor(seg.type)"
      >
        <i :class="segmentIcon(seg.type)" class="w-3 h-3" />
        {{ segmentName(seg) }}
        <button
          type="button"
          class="ml-0.5 hover:opacity-70 transition-opacity"
          @click="removeSegment(seg)"
        >
          <i class="i-lucide-x w-3 h-3" />
        </button>
      </span>
    </div>

    <p v-if="message" class="text-xs text-n-ruby-11">{{ message }}</p>

    <!-- Add buttons -->
    <div class="flex gap-2 flex-wrap">
      <Button
        type="button"
        variant="faded"
        color="slate"
        size="xs"
        icon="i-lucide-tag"
        :label="t('CAMPAIGN.AUDIENCE_BUILDER.BUTTONS.LABELS')"
        :class="activePanel === 'label' ? 'bg-n-alpha-3' : ''"
        @click="openPanel('label')"
      />
      <Button
        type="button"
        variant="faded"
        color="slate"
        size="xs"
        icon="i-lucide-building-2"
        :label="t('CAMPAIGN.AUDIENCE_BUILDER.BUTTONS.COMPANIES')"
        :class="activePanel === 'company' ? 'bg-n-alpha-3' : ''"
        @click="openPanel('company')"
      />
      <Button
        type="button"
        variant="faded"
        color="slate"
        size="xs"
        icon="i-lucide-sliders-horizontal"
        :label="t('CAMPAIGN.AUDIENCE_BUILDER.BUTTONS.ATTRIBUTES')"
        :class="activePanel === 'attribute' ? 'bg-n-alpha-3' : ''"
        @click="openPanel('attribute')"
      />
      <Button
        type="button"
        variant="faded"
        color="slate"
        size="xs"
        icon="i-lucide-upload"
        :label="t('CAMPAIGN.AUDIENCE_BUILDER.BUTTONS.IMPORT')"
        :class="activePanel === 'import' ? 'bg-n-alpha-3' : ''"
        @click="openPanel('import')"
      />
    </div>

    <!-- Label picker panel -->
    <div
      v-if="activePanel === 'label'"
      class="border border-n-weak rounded-xl p-4 bg-n-alpha-1 flex flex-col gap-3"
    >
      <p class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide">
        {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.LABELS.TITLE') }}
      </p>
      <TagMultiSelectComboBox
        v-model="selectedLabelIds"
        :options="labelOptions"
        :label="t('CAMPAIGN.AUDIENCE_BUILDER.BUTTONS.LABELS')"
        :placeholder="t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.LABELS.SEARCH_PLACEHOLDER')"
        class="[&>div>button]:bg-n-alpha-black2"
      />
      <div class="flex gap-2">
        <Button
          type="button"
          :label="t('CAMPAIGN.AUDIENCE_BUILDER.ADD')"
          size="sm"
          icon="i-lucide-plus"
          :disabled="!selectedLabelIds.length"
          @click="addLabels"
        />
        <Button
          type="button"
          :label="t('CAMPAIGN.AUDIENCE_BUILDER.CANCEL')"
          variant="faded"
          color="slate"
          size="sm"
          @click="activePanel = null"
        />
      </div>
    </div>

    <!-- Company picker panel -->
    <div
      v-if="activePanel === 'company'"
      class="border border-n-weak rounded-xl p-4 bg-n-alpha-1 flex flex-col gap-3"
    >
      <p class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide">
        {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.COMPANIES.TITLE') }}
      </p>
      <ComboBox
        v-model="selectedCompanyId"
        :options="companyOptions"
        :use-api-results="true"
        :placeholder="t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.COMPANIES.SEARCH_PLACEHOLDER')"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak"
        @search="searchCompanies"
      />
      <div class="flex gap-2">
        <Button
          type="button"
          :label="t('CAMPAIGN.AUDIENCE_BUILDER.ADD')"
          size="sm"
          icon="i-lucide-plus"
          :disabled="!selectedCompanyId"
          @click="addCompany"
        />
        <Button
          type="button"
          :label="t('CAMPAIGN.AUDIENCE_BUILDER.CANCEL')"
          variant="faded"
          color="slate"
          size="sm"
          @click="activePanel = null"
        />
      </div>
    </div>

    <!-- Attribute picker panel -->
    <div
      v-if="activePanel === 'attribute'"
      class="border border-n-weak rounded-xl p-4 bg-n-alpha-1 flex flex-col gap-3"
    >
      <p class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide">
        {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.TITLE') }}
      </p>
      <div v-if="attributeOptions.length === 0" class="text-sm text-n-slate-9">
        {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.EMPTY') }}
      </div>
      <template v-else>
        <div class="flex flex-col gap-1">
          <label class="text-xs text-n-slate-10">
            {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.ATTRIBUTE_LABEL') }}
          </label>
          <select
            v-model="selectedAttributeKey"
            class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="attributeValue = ''"
          >
            <option value="" disabled>
              {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.ATTRIBUTE_PLACEHOLDER') }}
            </option>
            <option v-for="opt in attributeOptions" :key="opt.value" :value="opt.value">
              {{ opt.label }}
            </option>
          </select>
        </div>

        <div v-if="selectedAttributeDef" class="flex flex-col gap-1">
          <label class="text-xs text-n-slate-10">
            {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.VALUE_LABEL') }}
          </label>

          <!-- List type: dropdown -->
          <select
            v-if="selectedAttributeDef.displayType === 'list'"
            v-model="attributeValue"
            class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="" disabled>
              {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.SELECT_PLACEHOLDER') }}
            </option>
            <option v-for="val in selectedAttributeDef.values" :key="val" :value="val">
              {{ val }}
            </option>
          </select>

          <!-- Checkbox type: true/false -->
          <select
            v-else-if="selectedAttributeDef.displayType === 'checkbox'"
            v-model="attributeValue"
            class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="" disabled>
              {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.SELECT_PLACEHOLDER') }}
            </option>
            <option value="true">{{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.YES') }}</option>
            <option value="false">{{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.NO') }}</option>
          </select>

          <!-- Default: text input -->
          <input
            v-else
            v-model="attributeValue"
            type="text"
            :placeholder="t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.ATTRIBUTES.TEXT_PLACEHOLDER')"
            class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-9 outline-none focus:border-n-brand"
          />
        </div>

        <div class="flex gap-2">
          <Button
            type="button"
            :label="t('CAMPAIGN.AUDIENCE_BUILDER.ADD')"
            size="sm"
            icon="i-lucide-plus"
            :disabled="!selectedAttributeKey || !attributeValue.toString().trim()"
            @click="addAttribute"
          />
          <Button
            type="button"
            :label="t('CAMPAIGN.AUDIENCE_BUILDER.CANCEL')"
            variant="faded"
            color="slate"
            size="sm"
            @click="activePanel = null"
          />
        </div>
      </template>
    </div>

    <!-- Import panel -->
    <div
      v-if="activePanel === 'import'"
      class="border border-n-weak rounded-xl p-4 bg-n-alpha-1 flex flex-col gap-3"
    >
      <p class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide">
        {{ t('CAMPAIGN.AUDIENCE_BUILDER.PANELS.IMPORT.TITLE') }}
      </p>
      <AudienceImportModal @add="handleImportAdd" @close="activePanel = null" />
      <Button
        type="button"
        :label="t('CAMPAIGN.AUDIENCE_BUILDER.CLOSE')"
        variant="faded"
        color="slate"
        size="sm"
        class="self-start"
        @click="activePanel = null"
      />
    </div>
  </div>
</template>
