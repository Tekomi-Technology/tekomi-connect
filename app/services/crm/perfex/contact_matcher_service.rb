class Crm::Perfex::ContactMatcherService
  def initialize(contact_client)
    @contact_client = contact_client
  end

  def match_all(contacts)
    perfex_contacts = @contact_client.fetch_all_contacts
    contacts.count { |contact| match_contact(contact, perfex_contacts) }
  end

  def match_one(contact)
    perfex_contacts = @contact_client.fetch_all_contacts
    match_contact(contact, perfex_contacts)
    contact
  end

  def search(query)
    return [] if query.blank?

    perfex_contacts = @contact_client.fetch_all_contacts
    downcased_query = query.downcase

    perfex_contacts.select do |c|
      full_name = "#{c['firstname']} #{c['lastname']}"
      [full_name, c['email'], c['phonenumber']].any? { |field| field.to_s.downcase.include?(downcased_query) }
    end
  end

  def link_one(contact, perfex_contact_id)
    perfex_contacts = @contact_client.fetch_all_contacts
    perfex_contact = perfex_contacts.find { |c| c['id'] == perfex_contact_id.to_s }
    return contact if perfex_contact.nil?

    mark_matched(contact, perfex_contact)
    contact
  end

  private

  def match_contact(contact, perfex_contacts)
    matched = find_by_email(contact, perfex_contacts) || find_by_phone(contact, perfex_contacts)

    matched ? mark_matched(contact, matched) : mark_failed(contact)
    matched.present?
  end

  def find_by_email(contact, perfex_contacts)
    return nil if contact.email.blank?

    perfex_contacts.find { |c| c['email'].present? && c['email'].casecmp?(contact.email) }
  end

  def find_by_phone(contact, perfex_contacts)
    return nil if contact.phone_number.blank?

    perfex_contacts.find { |c| c['phonenumber'].present? && normalize(c['phonenumber']) == normalize(contact.phone_number) }
  end

  def normalize(phone_number)
    digits = phone_number.to_s.gsub(/\D/, '')
    digits = digits.delete_prefix('84') if digits.start_with?('84')
    digits.delete_prefix('0')
  end

  def mark_matched(contact, perfex_contact)
    name = "#{perfex_contact['firstname']} #{perfex_contact['lastname']}".strip
    external = (contact.additional_attributes['external'] || {}).merge(
      'perfex_contact_id' => perfex_contact['id'],
      'perfex_customer_id' => perfex_contact['userid']
    )
    crm = (contact.additional_attributes['crm'] || {}).merge(
      'name' => name,
      'matched_at' => Time.current.iso8601
    )
    crm.delete('match_failed_at')

    contact.assign_attributes(additional_attributes: contact.additional_attributes.merge('external' => external, 'crm' => crm))
    contact.name = name if name.present?
    contact.phone_number = perfex_contact['phonenumber'] if perfex_contact['phonenumber'].present?
    contact.save!
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex contact sync skipped for contact #{contact.id}: #{e.message}"
    contact.phone_number = contact.phone_number_was
    contact.name = contact.name_was
    contact.save!
  end

  def mark_failed(contact)
    already_failed = contact.additional_attributes.dig('external', 'perfex_contact_id').blank? &&
                      contact.additional_attributes.dig('crm', 'match_failed_at').present?
    return if already_failed

    crm = (contact.additional_attributes['crm'] || {}).merge('match_failed_at' => Time.current.iso8601)
    contact.update!(additional_attributes: contact.additional_attributes.merge('crm' => crm))
  end
end
