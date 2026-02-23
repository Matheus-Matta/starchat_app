<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useConfig } from 'dashboard/composables/useConfig';
import BaseInfo from 'dashboard/components-next/AssignmentPolicy/components/BaseInfo.vue';
import RadioCard from 'dashboard/components-next/AssignmentPolicy/components/RadioCard.vue';
import FairDistribution from 'dashboard/components-next/AssignmentPolicy/components/FairDistribution.vue';
import DataTable from 'dashboard/components-next/AssignmentPolicy/components/DataTable.vue';
import AddDataDropdown from 'dashboard/components-next/AssignmentPolicy/components/AddDataDropdown.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  OPTIONS,
  ROUND_ROBIN,
  BALANCED,
  EQUAL_DISTRIBUTION,
  CUSTOM,
  EARLIEST_CREATED,
  LONGEST_WAITING,
  DEFAULT_FAIR_DISTRIBUTION_LIMIT,
  DEFAULT_FAIR_DISTRIBUTION_WINDOW,
  DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS,
  DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD,
} from 'dashboard/routes/dashboard/settings/assignmentPolicy/constants';

const props = defineProps({
  initialData: {
    type: Object,
    default: () => ({
      name: '',
      description: '',
      enabled: true,
      assignmentOrder: ROUND_ROBIN,
      conversationPriority: EARLIEST_CREATED,
      fairDistributionLimit: DEFAULT_FAIR_DISTRIBUTION_LIMIT,
      fairDistributionWindow: DEFAULT_FAIR_DISTRIBUTION_WINDOW,
      equalDistributionWindowHours: DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS,
      equalDistributionBalanceThreshold: DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD,
    }),
  },
  mode: {
    type: String,
    required: true,
    validator: value => ['CREATE', 'EDIT'].includes(value),
  },
  policyInboxes: { type: Array, default: () => [] },
  inboxList: { type: Array, default: () => [] },
  showInboxSection: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
  isInboxLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'addInbox', 'deleteInbox', 'validationChange']);

const { t } = useI18n();
const { isEnterprise } = useConfig();

const BASE_KEY = 'ASSIGNMENT_POLICY.AGENT_ASSIGNMENT_POLICY';

// ---------------------------------------------------------------------------
// Derive UI operation mode from saved policy data (backwards-compat)
// ---------------------------------------------------------------------------
const deriveOperationMode = data => {
  if (!data) return ROUND_ROBIN;
  const order = data.assignmentOrder;
  // balanced (legacy) and equal_distribution both map to the ED mode
  if (order === EQUAL_DISTRIBUTION || order === BALANCED) return EQUAL_DISTRIBUTION;
  // round_robin with custom fair-distribution settings → Custom
  const hasCustomFair =
    (data.fairDistributionLimit != null && data.fairDistributionLimit !== DEFAULT_FAIR_DISTRIBUTION_LIMIT) ||
    (data.fairDistributionWindow != null && data.fairDistributionWindow !== DEFAULT_FAIR_DISTRIBUTION_WINDOW);
  if (hasCustomFair) return CUSTOM;
  return ROUND_ROBIN;
};

// ---------------------------------------------------------------------------
// Reactive state — one flat object, sections keyed by prefix
// ---------------------------------------------------------------------------
const state = reactive({
  name: '',
  description: '',
  enabled: true,
  operationMode: ROUND_ROBIN,

  // --- ROUND ROBIN sub-config ---
  rrConversationPriority: EARLIEST_CREATED,

  // --- EQUAL DISTRIBUTION sub-config ---
  edConversationPriority: EARLIEST_CREATED,
  equalDistributionWindowHours: DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS,
  equalDistributionBalanceThreshold: DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD,

  // --- CUSTOM sub-config ---
  customAssignmentOrder: ROUND_ROBIN,
  customConversationPriority: EARLIEST_CREATED,
  customFairDistributionLimit: DEFAULT_FAIR_DISTRIBUTION_LIMIT,
  customFairDistributionWindow: DEFAULT_FAIR_DISTRIBUTION_WINDOW,
  customWindowUnit: 'hours',
  // shown only when customAssignmentOrder === EQUAL_DISTRIBUTION
  customEdWindowHours: DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS,
  customEdBalanceThreshold: DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD,
});

const validationState = ref({ isValid: false });

// ---------------------------------------------------------------------------
// Computed helpers
// ---------------------------------------------------------------------------
const operationModeOptions = computed(() =>
  OPTIONS.OPERATION_MODES.map((key, idx) => ({
    key,
    label: t(`${BASE_KEY}.FORM.OPERATION_MODE.${key.toUpperCase()}.LABEL`),
    description: t(`${BASE_KEY}.FORM.OPERATION_MODE.${key.toUpperCase()}.DESCRIPTION`),
    isActive: state.operationMode === key,
    // last mode (Custom) spans the full row in the 2-col grid
    spanFull: idx === OPTIONS.OPERATION_MODES.length - 1,
  }))
);

const priorityOptions = stateKey =>
  OPTIONS.PRIORITY.map(key => ({
    key,
    label: t(`${BASE_KEY}.FORM.ASSIGNMENT_PRIORITY.${key.toUpperCase()}.LABEL`),
    description: t(`${BASE_KEY}.FORM.ASSIGNMENT_PRIORITY.${key.toUpperCase()}.DESCRIPTION`),
    isActive: state[stateKey] === key,
  }));

const rrPriorityOptions = computed(() => priorityOptions('rrConversationPriority'));
const edPriorityOptions = computed(() => priorityOptions('edConversationPriority'));
const customPriorityOptions = computed(() => priorityOptions('customConversationPriority'));

const customOrderOptions = computed(() =>
  OPTIONS.ORDER.map(key => ({
    key,
    label: t(`${BASE_KEY}.FORM.ASSIGNMENT_ORDER.${key.toUpperCase()}.LABEL`),
    description: t(`${BASE_KEY}.FORM.ASSIGNMENT_ORDER.${key.toUpperCase()}.DESCRIPTION`),
    isActive: state.customAssignmentOrder === key,
  }))
);

const isRoundRobinMode = computed(() => state.operationMode === ROUND_ROBIN);
const isEDMode = computed(() => state.operationMode === EQUAL_DISTRIBUTION);
const isCustomMode = computed(() => state.operationMode === CUSTOM);
const customOrderIsED = computed(() => state.customAssignmentOrder === EQUAL_DISTRIBUTION);

const buttonLabel = computed(() =>
  t(`${BASE_KEY}.${props.mode.toUpperCase()}.${props.mode}_BUTTON`)
);

// ---------------------------------------------------------------------------
// Form actions
// ---------------------------------------------------------------------------
const handleValidationChange = validation => {
  validationState.value = validation;
  emit('validationChange', validation);
};

const resetForm = () => {
  Object.assign(state, {
    name: '',
    description: '',
    enabled: true,
    operationMode: ROUND_ROBIN,
    rrConversationPriority: EARLIEST_CREATED,
    edConversationPriority: EARLIEST_CREATED,
    equalDistributionWindowHours: DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS,
    equalDistributionBalanceThreshold: DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD,
    customAssignmentOrder: ROUND_ROBIN,
    customConversationPriority: EARLIEST_CREATED,
    customFairDistributionLimit: DEFAULT_FAIR_DISTRIBUTION_LIMIT,
    customFairDistributionWindow: DEFAULT_FAIR_DISTRIBUTION_WINDOW,
    customWindowUnit: 'hours',
    customEdWindowHours: DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS,
    customEdBalanceThreshold: DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD,
  });
};

const buildPayload = () => {
  const base = { name: state.name, description: state.description, enabled: state.enabled };

  if (state.operationMode === ROUND_ROBIN) {
    return {
      ...base,
      assignmentOrder: ROUND_ROBIN,
      conversationPriority: state.rrConversationPriority,
      fairDistributionLimit: DEFAULT_FAIR_DISTRIBUTION_LIMIT,
      fairDistributionWindow: DEFAULT_FAIR_DISTRIBUTION_WINDOW,
    };
  }

  if (state.operationMode === EQUAL_DISTRIBUTION) {
    return {
      ...base,
      assignmentOrder: EQUAL_DISTRIBUTION,
      conversationPriority: state.edConversationPriority,
      fairDistributionLimit: DEFAULT_FAIR_DISTRIBUTION_LIMIT,
      fairDistributionWindow: DEFAULT_FAIR_DISTRIBUTION_WINDOW,
      equalDistributionWindowHours: Number(state.equalDistributionWindowHours),
      equalDistributionBalanceThreshold: Number(state.equalDistributionBalanceThreshold),
    };
  }

  // CUSTOM
  const payload = {
    ...base,
    assignmentOrder: state.customAssignmentOrder,
    conversationPriority: state.customConversationPriority,
    fairDistributionLimit: state.customFairDistributionLimit,
    fairDistributionWindow: state.customFairDistributionWindow,
  };
  if (state.customAssignmentOrder === EQUAL_DISTRIBUTION) {
    payload.equalDistributionWindowHours = Number(state.customEdWindowHours);
    payload.equalDistributionBalanceThreshold = Number(state.customEdBalanceThreshold);
  }
  return payload;
};

const handleSubmit = () => emit('submit', buildPayload());

// ---------------------------------------------------------------------------
// Hydrate state when initialData arrives
// ---------------------------------------------------------------------------
watch(
  () => props.initialData,
  newData => {
    if (!newData) return;
    const mode = deriveOperationMode(newData);
    const isLegacyBalanced = newData.assignmentOrder === BALANCED;

    Object.assign(state, {
      name: newData.name ?? '',
      description: newData.description ?? '',
      enabled: newData.enabled ?? false,
      operationMode: mode,

      // RR
      rrConversationPriority:
        mode === ROUND_ROBIN ? (newData.conversationPriority ?? EARLIEST_CREATED) : EARLIEST_CREATED,

      // ED (also hydrate from legacy balanced — treat window_hours=0 for balanced)
      edConversationPriority:
        mode === EQUAL_DISTRIBUTION ? (newData.conversationPriority ?? EARLIEST_CREATED) : EARLIEST_CREATED,
      equalDistributionWindowHours: isLegacyBalanced
        ? 0
        : (newData.equalDistributionWindowHours ?? DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS),
      equalDistributionBalanceThreshold:
        newData.equalDistributionBalanceThreshold ?? DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD,

      // Custom
      customAssignmentOrder: mode === CUSTOM ? (newData.assignmentOrder ?? ROUND_ROBIN) : ROUND_ROBIN,
      customConversationPriority:
        mode === CUSTOM ? (newData.conversationPriority ?? EARLIEST_CREATED) : EARLIEST_CREATED,
      customFairDistributionLimit:
        newData.fairDistributionLimit ?? DEFAULT_FAIR_DISTRIBUTION_LIMIT,
      customFairDistributionWindow:
        newData.fairDistributionWindow ?? DEFAULT_FAIR_DISTRIBUTION_WINDOW,
      customEdWindowHours:
        newData.equalDistributionWindowHours ?? DEFAULT_EQUAL_DISTRIBUTION_WINDOW_HOURS,
      customEdBalanceThreshold:
        newData.equalDistributionBalanceThreshold ?? DEFAULT_EQUAL_DISTRIBUTION_BALANCE_THRESHOLD,
    });
  },
  { immediate: true, deep: true }
);

defineExpose({ resetForm });
</script>

<template>
  <form @submit.prevent="handleSubmit">
    <div class="flex flex-col gap-4 divide-y divide-n-weak mb-4">
      <!-- Basic info: name, description, status -->
      <BaseInfo
        v-model:policy-name="state.name"
        v-model:description="state.description"
        v-model:enabled="state.enabled"
        :name-label="t(`${BASE_KEY}.FORM.NAME.LABEL`)"
        :name-placeholder="t(`${BASE_KEY}.FORM.NAME.PLACEHOLDER`)"
        :description-label="t(`${BASE_KEY}.FORM.DESCRIPTION.LABEL`)"
        :description-placeholder="t(`${BASE_KEY}.FORM.DESCRIPTION.PLACEHOLDER`)"
        :status-label="t(`${BASE_KEY}.FORM.STATUS.LABEL`)"
        :status-placeholder="
          t(`${BASE_KEY}.FORM.STATUS.${state.enabled ? 'ACTIVE' : 'INACTIVE'}`)
        "
        @validation-change="handleValidationChange"
      />

      <!-- ─── Operation Mode cards ─── -->
      <div class="py-4 flex flex-col items-start gap-5 w-full">
        <WithLabel
          :label="t(`${BASE_KEY}.FORM.OPERATION_MODE.LABEL`)"
          name="operationMode"
          class="w-full flex items-start flex-col gap-3"
        >
          <div class="grid grid-cols-1 xs:grid-cols-2 gap-4 w-full">
            <RadioCard
              v-for="option in operationModeOptions"
              :id="option.key"
              :key="option.key"
              :class="{ 'xs:col-span-2': option.spanFull }"
              :label="option.label"
              :description="option.description"
              :is-active="option.isActive"
              @select="state.operationMode = option.key"
            />
          </div>
        </WithLabel>

        <!-- ──────────────────────────
             ROUND ROBIN sub-config
        ────────────────────────── -->
        <div
          v-if="isRoundRobinMode"
          class="w-full rounded-xl border border-n-weak overflow-hidden"
        >
          <div class="px-4 py-3 bg-n-solid-2 border-b border-n-weak">
            <p class="text-sm font-semibold text-n-slate-12 mb-0">
              {{ t(`${BASE_KEY}.FORM.ASSIGNMENT_PRIORITY.LABEL`) }}
            </p>
            <p class="text-xs text-n-slate-11 mb-0 mt-0.5">
              {{ t(`${BASE_KEY}.FORM.ASSIGNMENT_PRIORITY.DESCRIPTION`) }}
            </p>
          </div>
          <div class="p-4 bg-n-solid-1">
            <div class="grid grid-cols-1 xs:grid-cols-2 gap-3 w-full">
              <RadioCard
                v-for="option in rrPriorityOptions"
                :id="`rr-${option.key}`"
                :key="option.key"
                :label="option.label"
                :description="option.description"
                :is-active="option.isActive"
                @select="state.rrConversationPriority = option.key"
              />
            </div>
          </div>
        </div>

        <!-- ──────────────────────────────────────
             EQUAL DISTRIBUTION sub-config
        ────────────────────────────────────── -->
        <div
          v-if="isEDMode"
          class="w-full rounded-xl border border-n-weak overflow-hidden"
        >
          <!-- Medição de carga -->
          <div class="px-4 py-3 bg-n-solid-2 border-b border-n-weak">
            <p class="text-sm font-semibold text-n-slate-12 mb-0">
              {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.CONFIG_DESCRIPTION`) }}
            </p>
          </div>
          <div class="p-4 bg-n-solid-1 flex flex-col gap-5">
            <!-- Window + Threshold -->
            <div class="grid grid-cols-1 xs:grid-cols-2 gap-4">
              <div class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-slate-12">
                  {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.WINDOW_HOURS_LABEL`) }}
                </label>
                <Input
                  v-model="state.equalDistributionWindowHours"
                  type="number"
                  placeholder="24"
                  :min="0"
                />
                <p class="text-xs text-n-slate-11 mb-0">
                  {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.WINDOW_HOURS_HINT`) }}
                </p>
              </div>
              <div class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-slate-12">
                  {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.THRESHOLD_LABEL`) }}
                </label>
                <Input
                  v-model="state.equalDistributionBalanceThreshold"
                  type="number"
                  placeholder="20"
                  :min="0"
                  :max="100"
                />
                <p class="text-xs text-n-slate-11 mb-0">
                  {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.THRESHOLD_HINT`) }}
                </p>
              </div>
            </div>

            <!-- Divider -->
            <hr class="border-n-weak m-0" />

            <!-- Priority -->
            <div class="flex flex-col gap-3">
              <div>
                <p class="text-sm font-semibold text-n-slate-12 mb-0">
                  {{ t(`${BASE_KEY}.FORM.ASSIGNMENT_PRIORITY.LABEL`) }}
                </p>
                <p class="text-xs text-n-slate-11 mb-0 mt-0.5">
                  {{ t(`${BASE_KEY}.FORM.ASSIGNMENT_PRIORITY.DESCRIPTION`) }}
                </p>
              </div>
              <div class="grid grid-cols-1 xs:grid-cols-2 gap-3 w-full">
                <RadioCard
                  v-for="option in edPriorityOptions"
                  :id="`ed-${option.key}`"
                  :key="option.key"
                  :label="option.label"
                  :description="option.description"
                  :is-active="option.isActive"
                  @select="state.edConversationPriority = option.key"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- ──────────────────────────
             CUSTOM sub-config
        ────────────────────────── -->
        <div
          v-if="isCustomMode"
          class="w-full rounded-xl border border-n-weak overflow-hidden"
        >
          <!-- Seção: ordem -->
          <div class="px-4 py-3 bg-n-solid-2 border-b border-n-weak">
            <p class="text-sm font-semibold text-n-slate-12 mb-0">
              {{ t(`${BASE_KEY}.FORM.ASSIGNMENT_ORDER.LABEL`) }}
            </p>
          </div>
          <div class="p-4 bg-n-solid-1 flex flex-col gap-5">
            <div class="grid grid-cols-1 xs:grid-cols-2 gap-3 w-full">
              <RadioCard
                v-for="option in customOrderOptions"
                :id="`custom-order-${option.key}`"
                :key="option.key"
                :label="option.label"
                :description="option.description"
                :is-active="option.isActive"
                @select="state.customAssignmentOrder = option.key"
              />
            </div>

            <!-- ED config when order = equal_distribution -->
            <div
              v-if="customOrderIsED"
              class="rounded-lg border border-n-weak overflow-hidden"
            >
              <div class="px-3 py-2 bg-n-solid-2 border-b border-n-weak">
                <p class="text-xs font-semibold text-n-slate-11 mb-0 uppercase tracking-wide">
                  {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.CONFIG_DESCRIPTION`) }}
                </p>
              </div>
              <div class="grid grid-cols-1 xs:grid-cols-2 gap-4 p-3 bg-n-alpha-1">
                <div class="flex flex-col gap-1">
                  <label class="text-sm font-medium text-n-slate-12">
                    {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.WINDOW_HOURS_LABEL`) }}
                  </label>
                  <Input
                    v-model="state.customEdWindowHours"
                    type="number"
                    placeholder="24"
                    :min="0"
                  />
                  <p class="text-xs text-n-slate-11 mb-0">
                    {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.WINDOW_HOURS_HINT`) }}
                  </p>
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-sm font-medium text-n-slate-12">
                    {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.THRESHOLD_LABEL`) }}
                  </label>
                  <Input
                    v-model="state.customEdBalanceThreshold"
                    type="number"
                    placeholder="20"
                    :min="0"
                    :max="100"
                  />
                  <p class="text-xs text-n-slate-11 mb-0">
                    {{ t(`${BASE_KEY}.FORM.OPERATION_MODE.EQUAL_DISTRIBUTION.THRESHOLD_HINT`) }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Seção: prioridade -->
          <div class="px-4 py-3 bg-n-solid-2 border-t border-b border-n-weak">
            <p class="text-sm font-semibold text-n-slate-12 mb-0">
              {{ t(`${BASE_KEY}.FORM.ASSIGNMENT_PRIORITY.LABEL`) }}
            </p>
            <p class="text-xs text-n-slate-11 mb-0 mt-0.5">
              {{ t(`${BASE_KEY}.FORM.ASSIGNMENT_PRIORITY.DESCRIPTION`) }}
            </p>
          </div>
          <div class="p-4 bg-n-solid-1 flex flex-col gap-5">
            <div class="grid grid-cols-1 xs:grid-cols-2 gap-3 w-full">
              <RadioCard
                v-for="option in customPriorityOptions"
                :id="`custom-priority-${option.key}`"
                :key="option.key"
                :label="option.label"
                :description="option.description"
                :is-active="option.isActive"
                @select="state.customConversationPriority = option.key"
              />
            </div>

            <!-- Fair distribution -->
            <hr class="border-n-weak m-0" />
            <div class="flex flex-col gap-2">
              <div>
                <p class="text-sm font-semibold text-n-slate-12 mb-0">
                  {{ t(`${BASE_KEY}.FORM.FAIR_DISTRIBUTION.LABEL`) }}
                </p>
                <p class="text-sm text-n-slate-11 mb-0 mt-0.5">
                  {{ t(`${BASE_KEY}.FORM.FAIR_DISTRIBUTION.DESCRIPTION`) }}
                </p>
              </div>
              <FairDistribution
                v-model:fair-distribution-limit="state.customFairDistributionLimit"
                v-model:fair-distribution-window="state.customFairDistributionWindow"
                v-model:window-unit="state.customWindowUnit"
              />
            </div>
          </div>
        </div>
      </div>
    </div>

    <Button
      type="submit"
      :label="buttonLabel"
      :disabled="!validationState.isValid || isLoading"
      :is-loading="isLoading"
    />

    <!-- ─── Linked inboxes (edit page only) ─── -->
    <div
      v-if="showInboxSection"
      class="py-4 flex-col flex gap-4 border-t border-n-weak mt-6"
    >
      <div class="flex items-end gap-4 w-full justify-between">
        <div class="flex flex-col items-start gap-1 py-1">
          <label class="text-sm font-medium text-n-slate-12 py-1">
            {{ t(`${BASE_KEY}.FORM.INBOXES.LABEL`) }}
          </label>
          <p class="mb-0 text-n-slate-11 text-sm">
            {{ t(`${BASE_KEY}.FORM.INBOXES.DESCRIPTION`) }}
          </p>
        </div>
        <AddDataDropdown
          :label="t(`${BASE_KEY}.FORM.INBOXES.ADD_BUTTON`)"
          :search-placeholder="t(`${BASE_KEY}.FORM.INBOXES.DROPDOWN.SEARCH_PLACEHOLDER`)"
          :items="inboxList"
          @add="$emit('addInbox', $event)"
        />
      </div>

      <!-- Auto-assignment warning -->
      <div class="flex items-start gap-2 rounded-lg border border-amber-200 bg-amber-50 dark:border-amber-800 dark:bg-amber-950 px-3 py-2.5">
        <span class="i-lucide-triangle-alert mt-0.5 shrink-0 text-amber-600 dark:text-amber-400 size-4" />
        <p class="mb-0 text-xs text-amber-800 dark:text-amber-300 leading-relaxed">
          {{ t(`${BASE_KEY}.FORM.INBOXES.AUTO_ASSIGNMENT_NOTICE`) }}
        </p>
      </div>

      <DataTable
        :items="policyInboxes"
        :is-fetching="isInboxLoading"
        :empty-state-message="t(`${BASE_KEY}.FORM.INBOXES.EMPTY_STATE`)"
        @delete="$emit('deleteInbox', $event)"
      />
    </div>
  </form>
</template>
