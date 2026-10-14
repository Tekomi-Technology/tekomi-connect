<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Banner from 'dashboard/components/ui/Banner.vue';

const TRIAL_WARNING_DAYS = 7;

const { t } = useI18n();
const { accountId } = useAccount();
const getAccount = useMapGetter('accounts/getAccount');

const license = computed(() => getAccount.value(accountId.value)?.license);

const banner = computed(() => {
  const info = license.value;
  if (!info) return null;
  const daysLeft = Math.max(info.days_left ?? 0, 0);

  switch (info.state) {
    case 'suspended':
      return { scheme: 'alert', message: t('LICENSE.SUSPENDED') };
    case 'restricted':
      return { scheme: 'alert', message: t('LICENSE.RESTRICTED') };
    case 'grace':
      return { scheme: 'alert', message: t('LICENSE.GRACE') };
    case 'trial':
      return info.days_left !== null && daysLeft <= TRIAL_WARNING_DAYS
        ? {
            scheme: 'warning',
            message: t('LICENSE.TRIAL_ENDING', { days: daysLeft }),
          }
        : {
            scheme: 'secondary',
            message: t('LICENSE.TRIAL', { days: daysLeft }),
          };
    default:
      return info.days_left !== null && info.days_left <= TRIAL_WARNING_DAYS
        ? {
            scheme: 'warning',
            message: t('LICENSE.EXPIRING', { days: daysLeft }),
          }
        : null;
  }
});
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Banner
    v-if="banner"
    :color-scheme="banner.scheme"
    :banner-message="banner.message"
  />
</template>
