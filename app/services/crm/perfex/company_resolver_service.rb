class Crm::Perfex::CompanyResolverService
  def initialize(customer_client)
    @customer_client = customer_client
    @cache = {}
  end

  # Resolves the Perfex customer id to a Chatwoot Company for the account,
  # creating one with the CRM customer details when first seen.
  def resolve(account, userid)
    return nil if userid.blank?

    key = [account.id, userid.to_s]
    return @cache[key] if @cache.key?(key)

    company = find_company(account, userid.to_s) || create_company(account, userid.to_s)
    @cache[key] = company&.id
  end

  private

  def find_company(account, userid)
    account.companies.find_by(
      "additional_attributes -> 'external' ->> 'perfex_customer_id' = ?", userid
    )
  end

  def create_company(account, userid)
    customer = @customer_client.show(userid).fetch('data', {})
    account.companies.create!(
      name: customer['company'].presence || "Perfex ##{userid}",
      additional_attributes: {
        'phonenumber' => customer['phonenumber'],
        'external' => { 'perfex_customer_id' => userid }
      }
    )
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex company creation skipped for userid=#{userid}: #{e.message}"
    nil
  end
end
