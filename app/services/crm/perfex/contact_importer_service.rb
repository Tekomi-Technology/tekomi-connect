class Crm::Perfex::ContactImporterService
  def initialize(contact_client, account)
    @contact_client = contact_client
    @account = account
  end

  def import_all
    perfex_contacts = @contact_client.fetch_all_contacts
    existing_emails = @account.contacts.where.not(email: [nil, '']).pluck(:email).map(&:downcase)

    perfex_contacts.count { |perfex_contact| import_contact(perfex_contact, existing_emails) }
  end

  private

  def import_contact(perfex_contact, existing_emails)
    email = perfex_contact['email']
    return false if email.blank?
    return false if existing_emails.include?(email.downcase)

    name = "#{perfex_contact['firstname']} #{perfex_contact['lastname']}".strip

    @account.contacts.create!(
      name: name.presence || email,
      email: email,
      phone_number: perfex_contact['phonenumber'].presence,
      additional_attributes: {
        'external' => { 'perfex_contact_id' => perfex_contact['id'], 'perfex_customer_id' => perfex_contact['userid'] },
        'crm' => { 'name' => name, 'matched_at' => Time.current.iso8601 }
      }
    )
    existing_emails << email.downcase
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex contact import skipped for email=#{email}: #{e.message}"
    false
  end
end
