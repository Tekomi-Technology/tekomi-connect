import { ref } from 'vue';

const senderKindFilter = ref('all');

export function useMessageFilter() {
  return { senderKindFilter };
}
