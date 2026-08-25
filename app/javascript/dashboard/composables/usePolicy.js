import { unref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';
import {
  getUserPermissions,
  hasPermissions,
} from 'dashboard/helper/permissionsHelper';
import { CLOUD_PAID_FEATURES } from 'dashboard/featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';

export function usePolicy() {
  const user = useMapGetter('getCurrentUser');
  const isFeatureEnabled = useMapGetter('accounts/isFeatureEnabledonAccount');
  const isOnChatwootCloud = useMapGetter('globalConfig/isOnChatwootCloud');

  const { isEnterprise } = useConfig();
  const { accountId } = useAccount();

  const getUserPermissionsForAccount = () => {
    return getUserPermissions(user.value, accountId.value);
  };

  const isFeatureFlagEnabled = featureFlag => {
    if (!featureFlag || !isOnChatwootCloud.value) return true;

    return isFeatureEnabled.value(accountId.value, featureFlag);
  };

  const checkPermissions = requiredPermissions => {
    if (!requiredPermissions || !requiredPermissions.length) return true;
    const userPermissions = getUserPermissionsForAccount();
    return hasPermissions(requiredPermissions, userPermissions);
  };

  const checkInstallationType = config => {
    if (Array.isArray(config) && config.length > 0) {
      const installationCheck = {
        [INSTALLATION_TYPES.ENTERPRISE]: isEnterprise,
        [INSTALLATION_TYPES.CLOUD]: isOnChatwootCloud.value,
        [INSTALLATION_TYPES.COMMUNITY]: true,
      };

      return config.some(type => installationCheck[type]);
    }

    return true;
  };

  const shouldShow = (featureFlag, permissions, installationTypes) => {
    const flag = unref(featureFlag);
    const perms = unref(permissions);
    const installation = unref(installationTypes);

    if (!checkPermissions(perms)) return false;
    if (!checkInstallationType(installation)) return false;

    if (!isOnChatwootCloud.value) return true;

    return isFeatureFlagEnabled(flag) || CLOUD_PAID_FEATURES.includes(flag);
  };

  const shouldShowPaywall = featureFlag => {
    const flag = unref(featureFlag);
    if (!flag || !isOnChatwootCloud.value) return false;

    return CLOUD_PAID_FEATURES.includes(flag) && !isFeatureFlagEnabled(flag);
  };

  return {
    checkPermissions,
    checkInstallationType,
    shouldShowPaywall,
    isFeatureFlagEnabled,
    shouldShow,
  };
}
