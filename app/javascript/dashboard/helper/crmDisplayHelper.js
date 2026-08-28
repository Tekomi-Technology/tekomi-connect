/**
 * Composes the visible sender name for conversations:
 * "<channel identity> (<customer name>)" — e.g. "Zalo User 5171570940670082586 (Vũ Trung)".
 */
export const getMappedContactName = sender =>
  sender?.additional_attributes?.crm?.name || '';

export const getSenderDisplayName = sender => {
  if (!sender?.name) return '';
  const mappedName = getMappedContactName(sender);
  return mappedName && mappedName !== sender.name
    ? `${sender.name} (${mappedName})`
    : sender.name;
};
