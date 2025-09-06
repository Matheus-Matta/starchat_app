<script setup>
import { reactive, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';

import NextButton from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

// estado do formulário
const state = reactive({
  channelName: '',
});

// regras Vuelidate
const rules = {
  channelName: { required },
};

const v$ = useVuelidate(rules, state);

const uiFlags = computed(() => store.getters['inboxes/getUIFlags']);
const accountId = computed(() => route.params.accountId);
const isEvolutionProvider = computed(
  () => route.query.provider === 'evolution'
);

async function createChannel() {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const evolutionChannel = await store.dispatch(
      'inboxes/createEvolutionChannel',
      {
        evolution_channel: { name: state.channelName },
      }
    );
    router.replace({
      name: 'settings_inboxes_qrcode',
      params: {
        page: 'new',
        inbox_id: evolutionChannel.id,
      },
      query: isEvolutionProvider.value
        ? { ...route.query }
        : { ...route.query, provider: 'evolution' },
    });
  } catch (error) {
    const msg =
      parseAPIErrorResponse(error) ||
      t('INBOX_MGMT.ADD.EVOLUTION.API.ERROR_MESSAGE');
    useAlert(msg);
  }
}
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="createChannel">
    <!-- Aviso / políticas da Meta -->
    <div class="p-4 rounded-lg border border-n-weak bg-n-solid-2">
      <h3 class="mb-1 text-sm font-medium text-slate-12">
        {{ t('INBOX_MGMT.ADD.EVOLUTION.WARNING_TITLE') }}
      </h3>
      <p class="text-sm text-slate-11">
        {{ t('INBOX_MGMT.ADD.EVOLUTION.WARNING_TEXT') }}
        <a
          class="underline"
          :href="t('INBOX_MGMT.ADD.EVOLUTION.WARNING_LINK_URL')"
          target="_blank"
          rel="noopener"
        >
          {{ t('INBOX_MGMT.ADD.EVOLUTION.WARNING_LINK_TEXT') }}
        </a>
      </p>
    </div>

    <!-- Nome da inbox -->
    <div>
      <label :class="{ error: v$.channelName.$error }" class="block">
        <span class="mb-1 block text-sm text-slate-12">
          {{ t('INBOX_MGMT.ADD.EVOLUTION.FIELDS.INBOX_NAME.LABEL') }}
        </span>
        <input
          v-model="state.channelName"
          type="text"
          class="cw-input w-full"
          :placeholder="
            t('INBOX_MGMT.ADD.EVOLUTION.FIELDS.INBOX_NAME.PLACEHOLDER')
          "
          @blur="v$.channelName.$touch()"
        />
        <span v-if="v$.channelName.$error" class="message text-sm text-ruby-11">
          {{ t('INBOX_MGMT.ADD.EVOLUTION.FIELDS.INBOX_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="w-full mt-2">
      <NextButton
        :is-loading="uiFlags.isCreating"
        type="submit"
        solid
        blue
        :label="t('INBOX_MGMT.ADD.EVOLUTION.ACTIONS.CREATE_INBOX')"
      />
    </div>
  </form>
</template>

<style scoped>
.cw-input {
  width: 100%;
  border: 1px solid rgb(var(--border-weak));
  border-radius: 0.5rem;
  padding: 0.5rem 0.75rem;
  font-size: 0.875rem;
  background-color: rgb(var(--solid-1));
  color: rgb(var(--slate-12));
}
.message {
  display: inline-block;
  margin-top: 0.25rem;
}
</style>
