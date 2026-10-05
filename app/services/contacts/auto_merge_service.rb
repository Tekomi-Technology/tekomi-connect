# Merges a contact with the other contacts of its account that share a strong key: the same
# email (case-insensitive) or the same phone number once normalized ("0901…" = "+84901…").
# This is what joins one customer's Zalo, Facebook, phone and email identities into one person.
#
# The oldest contact is kept. A pair that looks like two different people — different emails,
# different identifiers, different CRM contacts, or a blocked contact — is left alone for an
# agent to merge by hand, so a shared number (a company switchboard) never fuses colleagues.
class Contacts::AutoMergeService
  pattr_initialize [:contact!]

  def perform
    survivor = contact
    duplicates.each do |duplicate|
      next if different_people?(survivor, duplicate)

      base, mergee = [survivor, duplicate].sort_by(&:id)
      survivor = ContactMergeAction.new(account: contact.account, base_contact: base, mergee_contact: mergee).perform
      Rails.logger.info("Contacts::AutoMergeService merged contact #{mergee.id} into #{base.id} (account #{contact.account_id})")
    end
    survivor
  end

  private

  def duplicates
    (same_email.to_a + same_phone.to_a).uniq.sort_by(&:id)
  end

  def others
    contact.account.contacts.where.not(id: contact.id)
  end

  def same_email
    contact.email.present? ? others.where('LOWER(contacts.email) = ?', contact.email.downcase) : Contact.none
  end

  def same_phone
    contact.phone_number.present? ? others.with_normalized_phone(contact.phone_number) : Contact.none
  end

  def different_people?(one, other)
    return true if one.blocked? || other.blocked?

    conflicting?(one.email&.downcase, other.email&.downcase) ||
      conflicting?(one.identifier, other.identifier) ||
      conflicting?(crm_contact_id(one), crm_contact_id(other))
  end

  def conflicting?(value, other_value)
    value.present? && other_value.present? && value.to_s != other_value.to_s
  end

  def crm_contact_id(contact)
    contact.additional_attributes&.dig('external', 'perfex_contact_id')
  end
end
