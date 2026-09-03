class Crm::Perfex::ContactSyncService
  def initialize(account)
    @account = account
  end

  def sync(perfex_contacts)
    # Preload existing data in O(n) to avoid O(m*n) queries
    existing_by_perfex = @account.contacts
                                 .where("additional_attributes -> 'external' ->> 'perfex_contact_id' IS NOT NULL")
                                 .each_with_object({}) do |contact, hash|
      hash[contact.additional_attributes['external']['perfex_contact_id'].to_s] = contact
    end

    existing_by_email = @account.contacts.where.not(email: [nil, ''])
                                 .each_with_object({}) do |contact, hash|
      hash[contact.email.downcase] = contact
    end

    companies_map = @account.companies
                            .where("additional_attributes -> 'external' ->> 'perfex_customer_id' IS NOT NULL")
                            .each_with_object({}) do |company, hash|
      hash[company.additional_attributes['external']['perfex_customer_id'].to_s] = company
    end

    perfex_contacts.count do |perfex_contact|
      sync_contact(perfex_contact, existing_by_perfex, existing_by_email, companies_map)
    end
  end

  private

  def sync_contact(perfex_contact, existing_by_perfex, existing_by_email, companies_map)
    perfex_contact_id = perfex_contact['id'].to_s
    return false if perfex_contact_id.blank?

    existing = existing_by_perfex[perfex_contact_id]
    if existing
      return update_existing_contact(existing, perfex_contact, companies_map)
    end

    email = perfex_contact['email'].to_s.strip
    if email.present? && existing_by_email[email.downcase].present?
      return false
    end

    name = "#{perfex_contact['firstname']} #{perfex_contact['lastname']}".strip
    company_id = companies_map[perfex_contact['userid'].to_s]&.id

    contact = @account.contacts.create!(
      name: name.presence || email.presence || perfex_contact['phonenumber'].presence || "Perfex #{perfex_contact_id}",
      email: email.presence,
      phone_number: perfex_contact['phonenumber'].presence,
      company_id: company_id,
      additional_attributes: {
        'external' => { 'perfex_contact_id' => perfex_contact_id, 'perfex_customer_id' => perfex_contact['userid'].to_s },
        'crm' => { 'name' => name, 'matched_at' => Time.current.iso8601 }
      }
    )
    existing_by_perfex[perfex_contact_id] = contact
    existing_by_email[email.downcase] = contact if email.present?
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex contact sync skipped for perfex_contact_id=#{perfex_contact_id}: #{e.message}"
    false
  end

  def update_existing_contact(existing, perfex_contact, companies_map)
    name = "#{perfex_contact['firstname']} #{perfex_contact['lastname']}".strip
    new_email = perfex_contact['email'].presence
    new_phone = perfex_contact['phonenumber'].presence
    new_userid = perfex_contact['userid'].to_s
    new_company_id = companies_map[new_userid]&.id

    current_external = existing.additional_attributes['external'] || {}
    current_crm = existing.additional_attributes['crm'] || {}

    needs_update = false
    needs_update ||= current_crm['name'] != name && name.present?
    needs_update ||= current_external['perfex_customer_id'] != new_userid
    needs_update ||= new_email.present? && existing.email != new_email
    needs_update ||= new_phone.present? && existing.phone_number != new_phone
    needs_update ||= existing.company_id != new_company_id && new_company_id.present?

    return false unless needs_update

    new_external = current_external.merge('perfex_customer_id' => new_userid)
    new_crm = current_crm.merge('name' => name.presence || current_crm['name'], 'matched_at' => Time.current.iso8601)

    existing.update!(
      email: new_email || existing.email,
      phone_number: new_phone || existing.phone_number,
      company_id: new_company_id || existing.company_id,
      additional_attributes: existing.additional_attributes.merge('external' => new_external, 'crm' => new_crm)
    )
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex contact update skipped for perfex_contact_id=#{perfex_contact['id']}: #{e.message}"
    false
  end
end
