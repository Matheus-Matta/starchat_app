<script setup>
import { computed, h } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useImpersonation } from 'dashboard/composables/useImpersonation';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';
import Icon from 'next/icon/Icon.vue';
import Button from 'next/button/Button.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

const { t } = useI18n();
const store = useStore();
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const currentAccountId = useMapGetter('getCurrentAccountId');
const currentUserAutoOffline = useMapGetter('getCurrentUserAutoOffline');
const currentRole = useMapGetter('getCurrentRole');

const { isImpersonating } = useImpersonation();

const isAdmin = computed(() => currentRole.value === 'administrator');

const allStatusDefs = computed(() => {
  const base = [
    { value: 'online', color: 'bg-n-teal-9', label: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE') },
    { value: 'busy', color: 'bg-n-amber-9', label: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY') },
    { value: 'offline', color: 'bg-n-slate-9', label: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE') },
  ];
  if (isAdmin.value) {
    base.push({ value: 'invisible', color: 'bg-n-slate-6', label: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.INVISIBLE') });
  }
  return base;
});

const availabilityStatuses = computed(() =>
  allStatusDefs.value.map(s => ({
    ...s,
    icon: h('span', { class: [s.color, 'size-[12px] rounded'] }),
    active: currentUserAvailability.value === s.value,
  }))
);

const activeStatus = computed(
  () =>
    availabilityStatuses.value.find(s => s.active) ||
    availabilityStatuses.value.find(s => s.value === 'offline')
);

const autoOfflineToggle = computed({
  get: () => currentUserAutoOffline.value,
  set: autoOffline => {
    store.dispatch('updateAutoOffline', {
      accountId: currentAccountId.value,
      autoOffline,
    });
  },
});

function changeAvailabilityStatus(availability) {
  if (isImpersonating.value) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.IMPERSONATING_ERROR'));
    return;
  }
  try {
    store.dispatch('updateAvailability', {
      availability,
      account_id: currentAccountId.value,
    });
  } catch (error) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.SET_AVAILABILITY_ERROR'));
  }
}
</script>

<template>
  <DropdownSection class="[&>ul]:overflow-visible">
    <div class="grid gap-0">
      <DropdownItem preserve-open class="gap-1">
        <div class="flex-grow flex items-center gap-1 min-w-0">
          {{ $t('SIDEBAR.SET_YOUR_AVAILABILITY') }}
        </div>
        <DropdownContainer class="shrink-0">
          <template #trigger="{ toggle }">
            <Button
              size="sm"
              color="slate"
              variant="faded"
              icon="i-lucide-chevron-down"
              trailing-icon
              @click="toggle"
            >
              <div class="flex gap-1 items-center min-w-0 text-sm">
                <div class="p-1 flex-shrink-0">
                  <div class="size-2 rounded-sm" :class="activeStatus.color" />
                </div>
                <span class="truncate max-w-[7rem]">
                  {{ activeStatus.label }}
                </span>
              </div>
            </Button>
          </template>
          <DropdownBody class="min-w-32 z-20">
            <DropdownItem
              v-for="status in availabilityStatuses"
              :key="status.value"
              :label="status.label"
              :icon="status.icon"
              class="cursor-pointer"
              @click="changeAvailabilityStatus(status.value)"
            />
          </DropdownBody>
        </DropdownContainer>
      </DropdownItem>
      <DropdownItem>
        <div class="flex-grow min-w-0">
          {{ $t('SIDEBAR.SET_AUTO_OFFLINE.TEXT') }}
          <Icon
            v-tooltip.top="$t('SIDEBAR.SET_AUTO_OFFLINE.INFO_SHORT')"
            icon="i-lucide-info"
            class="inline-block align-middle ms-1 size-4 text-n-slate-10"
          />
        </div>
        <ToggleSwitch v-model="autoOfflineToggle" />
      </DropdownItem>
    </div>
  </DropdownSection>
</template>
