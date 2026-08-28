class Crm::Perfex::ContactMatcherService
  def initialize(contact_client:, customer_client:)
    @directory = Crm::Perfex::DirectoryCacheService.new(contact_client)
    @company_resolver = Crm::Perfex::CompanyResolverService.new(customer_client)
  end

  def match_all(contacts)
    perfex_contacts = @directory.fetch_all
    contacts.count { |contact| match_contact(contact, perfex_contacts) }
  end

  def match_one(contact, perfex_contacts = nil)
    perfex_contacts ||= @directory.fetch_all
    match_contact(contact, perfex_contacts)
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
    PhoneNumberNormalizer.normalize(phone_number)
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

    updates = { additional_attributes: contact.additional_attributes.merge('external' => external, 'crm' => crm) }
    company_id = @company_resolver.resolve(contact.account, perfex_contact['userid'])
    updates[:company_id] = company_id if company_id.present? && contact.company_id != company_id

    # Locally managed fields (name, phone_number) are never overwritten with CRM values.
    contact.assign_attributes(updates)
    contact.save!
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex contact match skipped for contact #{contact.id}: #{e.message}"
    contact.reload
  end

  def mark_failed(contact)
    already_failed = contact.additional_attributes.dig('external', 'perfex_contact_id').blank? &&
                      contact.additional_attributes.dig('crm', 'match_failed_at').present?
    return if already_failed

    crm = (contact.additional_attributes['crm'] || {}).merge('match_failed_at' => Time.current.iso8601)
    contact.update!(additional_attributes: contact.additional_attributes.merge('crm' => crm))
  end
end
