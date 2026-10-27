import { ref } from 'vue';

const analysisVersion = ref(0);

export function useConversationAnalysis() {
  const markAnalyzed = () => {
    analysisVersion.value += 1;
  };

  return {
    analysisVersion,
    markAnalyzed,
  };
}
