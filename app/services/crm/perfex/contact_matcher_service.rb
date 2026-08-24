class Crm::Perfex::ContactMatcherService
  def initialize(contact_client)
    @contact_client = contact_client
  end

  def match_all(contacts)
    perfex_contacts = @contact_client.fetch_all_contacts
    contacts.each { |contact| match_contact(contact, perfex_contacts) }
  end

  def match_one(contact)
    perfex_contacts = @contact_client.fetch_all_contacts
    match_contact(contact, perfex_contacts)
    contact
  end

  private

  def match_contact(contact, perfex_contacts)
    matched = find_by_email(contact, perfex_contacts) || find_by_phone(contact, perfex_contacts)

    matched ? mark_matched(contact, matched) : mark_failed(contact)
  end

  def find_by_email(contact, perfex_contacts)
    return nil if contact.email.blank?

    perfex_contacts.find { |c| c['email'].present? && c['email'].casecmp?(contact.email) }
  end

  def find_by_phone(contact, perfex_contacts)
    return nil if contact.phone_number.blank?

    perfex_contacts.find { |c| c['phonenumber'].present? && normalize(c['phonenumber']) == normalize(contact.phone_number) }
  end

  def mark_matched(contact, perfex_contact)
    external = (contact.additional_attributes['external'] || {}).merge(
      'perfex_contact_id' => perfex_contact['id'],
      'perfex_customer_id' => perfex_contact['userid']
    )
    crm = (contact.additional_attributes['crm'] || {}).merge(
      'name' => "#{perfex_contact['firstname']} #{perfex_contact['lastname']}".strip,
      'matched_at' => Time.current.iso8601
    )
    crm.delete('match_failed_at')

    contact.update!(additional_attributes: contact.additional_attributes.merge('external' => external, 'crm' => crm))
  end

  def mark_failed(contact)
    already_failed = contact.additional_attributes.dig('external', 'perfex_contact_id').blank? &&
                      contact.additional_attributes.dig('crm', 'match_failed_at').present?
    return if already_failed

    crm = (contact.additional_attributes['crm'] || {}).merge('match_failed_at' => Time.current.iso8601)
    contact.update!(additional_attributes: contact.additional_attributes.merge('crm' => crm))
  end

  def normalize(number)
    return '' if number.blank?

    digits = number.to_s.gsub(/\D/, '')
    digits = digits.delete_prefix('84') if digits.start_with?('84')
    digits.delete_prefix('0')
  end
end
