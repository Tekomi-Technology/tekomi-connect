class Crm::Perfex::CompanySyncService
  def initialize(account)
    @account = account
  end

  # Upserts Chatwoot companies from the cached CRM customer directory so the
  # company layer exists even before any contact is matched.
  def sync(customers)
    customers.count { |customer| sync_customer(customer) }
  end

  private

  def sync_customer(customer)
    userid = customer['userid'].to_s
    return false if userid.blank?
    return false if find_company(userid).present?

    @account.companies.create!(
      name: customer['company'].presence || "Perfex ##{userid}",
      additional_attributes: {
        'phonenumber' => customer['phonenumber'],
        'external' => { 'perfex_customer_id' => userid }
      }
    )
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex company sync skipped for userid=#{customer['userid']}: #{e.message}"
    false
  end

  def find_company(userid)
    @account.companies.find_by(
      "additional_attributes -> 'external' ->> 'perfex_customer_id' = ?", userid
    )
  end
end
