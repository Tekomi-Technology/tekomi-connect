<script>
import { useAdmin } from 'dashboard/composables/useAdmin';
import BackButton from '../../../components/widgets/BackButton.vue';

export default {
  components: {
    BackButton,
  },
  props: {
    headerTitle: {
      default: '',
      type: String,
    },
    icon: {
      default: '',
      type: String,
    },
    showBackButton: { type: Boolean, default: false },
    backUrl: {
      type: [String, Object],
      default: '',
    },
    backButtonLabel: {
      type: String,
      default: '',
    },
  },
  setup() {
    const { isAdmin } = useAdmin();
    return {
      isAdmin,
    };
  },
  computed: {
    iconClass() {
      return `icon ${this.icon} header--icon`;
    },
  },
};
</script>

<template>
  <div
    class="flex items-center justify-between gap-4 px-6 py-5 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
  >
    <h1 class="flex items-center mb-0 text-n-slate-12">
      <BackButton
        v-if="showBackButton"
        :button-label="backButtonLabel"
        :back-url="backUrl"
        class="ltr:mr-4 rtl:ml-4"
      />

      <slot />
      <span class="text-2xl font-semibold tracking-tight text-n-slate-12">
        {{ headerTitle }}
      </span>
    </h1>
  </div>
</template>
