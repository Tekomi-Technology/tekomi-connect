class Crm::Perfex::CustomerImporterService
  def initialize(customer_client, account)
    @customer_client = customer_client
    @account = account
  end

  def import_all
    customers = @customer_client.fetch_all_customers
    existing_perfex_ids = @account.companies.pluck(:additional_attributes).filter_map { |attrs| attrs.dig('external', 'perfex_customer_id') }

    customers.count { |customer| import_customer(customer, existing_perfex_ids) }
  end

  private

  def import_customer(customer, existing_perfex_ids)
    return false if customer['userid'].blank?
    return false if existing_perfex_ids.include?(customer['userid'])

    @account.companies.create!(
      name: customer['company'].presence || "Perfex ##{customer['userid']}",
      additional_attributes: {
        'phonenumber' => customer['phonenumber'],
        'external' => { 'perfex_customer_id' => customer['userid'] }
      }
    )
    existing_perfex_ids << customer['userid']
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex company import skipped for userid=#{customer['userid']}: #{e.message}"
    false
  end
end
