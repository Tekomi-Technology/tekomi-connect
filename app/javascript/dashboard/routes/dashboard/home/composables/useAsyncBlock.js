import { ref, shallowRef } from 'vue';

export function useAsyncBlock(fetcher) {
  const data = shallowRef(null);
  const isLoading = ref(false);
  const hasError = ref(false);

  const load = async () => {
    isLoading.value = true;
    hasError.value = false;
    try {
      data.value = await fetcher();
    } catch {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  };

  return { data, isLoading, hasError, load };
}
