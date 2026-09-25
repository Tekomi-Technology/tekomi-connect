import { ref } from 'vue';

const requestedConversationId = ref(null);
const analysisVersion = ref(0);

export function useConversationAnalysis() {
  const requestAnalysis = conversationId => {
    requestedConversationId.value = conversationId;
  };

  const clearRequest = () => {
    requestedConversationId.value = null;
  };

  const markAnalyzed = () => {
    analysisVersion.value += 1;
  };

  return {
    requestedConversationId,
    analysisVersion,
    requestAnalysis,
    clearRequest,
    markAnalyzed,
  };
}
