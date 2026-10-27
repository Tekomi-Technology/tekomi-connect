import { MESSAGE_TYPES } from '../constants';

export const SENDER_KINDS = Object.freeze({
  CUSTOMER: 'customer',
  AI: 'ai',
  AGENT: 'agent',
  AUTO: 'auto',
});

const AI_SENDER_TYPES = [
  'agent_bot',
  'tekomi_assistant',
  'AgentBot',
  'Tekomi::Assistant',
];

export const getSenderKind = ({
  messageType,
  private: isPrivate,
  sender,
  senderType,
  contentAttributes,
  additionalAttributes,
}) => {
  if (messageType === MESSAGE_TYPES.INCOMING) return SENDER_KINDS.CUSTOMER;
  if (messageType !== MESSAGE_TYPES.OUTGOING && !isPrivate) {
    return SENDER_KINDS.AUTO;
  }
  if (AI_SENDER_TYPES.includes(sender?.type ?? senderType)) {
    return SENDER_KINDS.AI;
  }
  if (isPrivate || contentAttributes?.externalEcho) return SENDER_KINDS.AGENT;
  if (!sender && !additionalAttributes?.senderName) return SENDER_KINDS.AUTO;
  return SENDER_KINDS.AGENT;
};
