/**
 * Composes the visible sender name for conversations:
 * "<channel identity> (<mapped customer name>)" — e.g.
 * "Zalo User 5171570940670082586 (Vũ Trung)" or "+84342387314 (Vũ Trung)".
 */
export const getMappedContactName = sender =>
  sender?.additional_attributes?.crm?.name ||
  sender?.additional_attributes?.mapped_contact_name ||
  '';

export const getSenderDisplayName = sender => {
  if (!sender?.name) return '';
  const mappedName = getMappedContactName(sender);
  return mappedName && mappedName !== sender.name
    ? `${sender.name} (${mappedName})`
    : sender.name;
};
