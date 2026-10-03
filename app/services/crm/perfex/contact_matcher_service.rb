class Crm::Perfex::ContactMatcherService
  def initialize(contact_client:, customer_client:)
    @directory = Crm::Perfex::DirectoryCacheService.new(contact_client)
    @company_resolver = Crm::Perfex::CompanyResolverService.new(customer_client)
  end

  def match_all(contacts)
    perfex_contacts = @directory.fetch_all
    email_map, phone_map = build_maps(perfex_contacts)
    contacts.count { |contact| match_contact(contact, perfex_contacts, email_map, phone_map) }
  end

  def match_one(contact, perfex_contacts = nil)
    perfex_contacts ||= @directory.fetch_all
    email_map, phone_map = build_maps(perfex_contacts)
    match_contact(contact, perfex_contacts, email_map, phone_map)
    contact
  end

  private

  def build_maps(perfex_contacts)
    email_map = {}
    phone_map = {}
    perfex_contacts.each do |c|
      email_map[c['email'].downcase] = c if c['email'].present?
      normalized = normalize(c['phonenumber']) if c['phonenumber'].present?
      phone_map[normalized] = c if normalized.present?
    end
    [email_map, phone_map]
  end

  def match_contact(contact, perfex_contacts, email_map, phone_map)
    matched = find_by_email(contact, email_map) || find_by_phone(contact, phone_map)

    matched ? mark_matched(contact, matched) : mark_failed(contact)
    matched.present?
  end

  def find_by_email(contact, email_map)
    return nil if contact.email.blank?

    email_map[contact.email.downcase]
  end

  def find_by_phone(contact, phone_map)
    return nil if contact.phone_number.blank?

    phone_map[normalize(contact.phone_number)]
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
