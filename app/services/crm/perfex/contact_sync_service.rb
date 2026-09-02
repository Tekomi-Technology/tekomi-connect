class Crm::Perfex::ContactSyncService
  def initialize(account)
    @account = account
  end

  def sync(perfex_contacts)
    perfex_contacts.count { |perfex_contact| sync_contact(perfex_contact) }
  end

  private

  def sync_contact(perfex_contact)
    perfex_contact_id = perfex_contact['id'].to_s
    return false if perfex_contact_id.blank?
    return false if find_by_perfex_id(perfex_contact_id).present?

    email = perfex_contact['email'].to_s.strip
    if email.present? && find_by_email(email).present?
      return false
    end

    name = "#{perfex_contact['firstname']} #{perfex_contact['lastname']}".strip
    company_id = resolve_company_id(perfex_contact['userid'])

    @account.contacts.create!(
      name: name.presence || email.presence || perfex_contact['phonenumber'].presence || "Perfex #{perfex_contact_id}",
      email: email.presence,
      phone_number: perfex_contact['phonenumber'].presence,
      company_id: company_id,
      additional_attributes: {
        'external' => { 'perfex_contact_id' => perfex_contact_id, 'perfex_customer_id' => perfex_contact['userid'].to_s },
        'crm' => { 'name' => name, 'matched_at' => Time.current.iso8601 }
      }
    )
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex contact sync skipped for perfex_contact_id=#{perfex_contact_id}: #{e.message}"
    false
  end

  def find_by_perfex_id(perfex_contact_id)
    @account.contacts.find_by("additional_attributes -> 'external' ->> 'perfex_contact_id' = ?", perfex_contact_id)
  end

  def find_by_email(email)
    @account.contacts.find_by('LOWER(email) = ?', email.downcase)
  end

  def resolve_company_id(userid)
    return nil if userid.blank?

    company = @account.companies.find_by("additional_attributes -> 'external' ->> 'perfex_customer_id' = ?", userid.to_s)
    company&.id
  end
end
