<script setup>
import { ref, reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  filterType: {
    type: Number,
    default: 1,
  },
});

const emit = defineEmits(['create']);
const { t } = useI18n();

const dialogRef = ref(null);
const uiFlags = useMapGetter('contacts/getUIFlags');
const isCreating = computed(() => uiFlags.value.isCreatingCustomView);

const state = reactive({
  name: '',
});

const rules = {
  name: { required },
};

const v$ = useVuelidate(rules, state);

const handleDialogConfirm = async () => {
  const isNameValid = await v$.value.$validate();
  if (!isNameValid) return;
  emit('create', {
    name: state.name,
    filter_type: props.filterType,
  });
  state.name = '';
  v$.value.$reset();
};

const isEditing = ref(false);

const open = ({ name = '', edit = false } = {}) => {
  state.name = name;
  isEditing.value = edit;
  dialogRef.value?.open();
};

defineExpose({ dialogRef, open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      isEditing
        ? t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.UPDATE_SEGMENT.TITLE')
        : t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.TITLE')
    "
    :confirm-button-label="
      isEditing
        ? t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.UPDATE_SEGMENT.CONFIRM')
        : t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.CONFIRM')
    "
    :is-loading="isCreating"
    :disable-confirm-button="isCreating"
    @confirm="handleDialogConfirm"
  >
    <Input
      v-model="state.name"
      :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.LABEL')"
      :placeholder="
        t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.PLACEHOLDER')
      "
      :message="
        v$.name.$error
          ? t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.ERROR')
          : ''
      "
      :message-type="v$.name.$error ? 'error' : 'info'"
    />
  </Dialog>
</template>
