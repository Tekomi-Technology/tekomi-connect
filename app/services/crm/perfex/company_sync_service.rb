class Crm::Perfex::CompanySyncService
  def initialize(account)
    @account = account
  end

  # Upserts Chatwoot companies from the cached CRM customer directory so the
  # company layer exists even before any contact is matched. Optimized to O(m+n)
  # with bulk preload and in-memory maps.
  def sync(customers)
    existing_map = @account.companies
                           .where("additional_attributes -> 'external' ->> 'perfex_customer_id' IS NOT NULL")
                           .each_with_object({}) do |company, hash|
      hash[company.additional_attributes['external']['perfex_customer_id'].to_s] = company
    end

    customers.count { |customer| sync_customer(customer, existing_map) }
  end

  private

  def sync_customer(customer, existing_map)
    userid = customer['userid'].to_s
    return false if userid.blank?

    existing = existing_map[userid]
    if existing
      new_name = customer['company'].presence || "Perfex ##{userid}"
      new_phone = customer['phonenumber']

      if existing.name != new_name || existing.additional_attributes['phonenumber'] != new_phone
        existing.update!(
          name: new_name,
          additional_attributes: existing.additional_attributes.merge('phonenumber' => new_phone)
        )
        return true
      end
      return false
    end

    company = @account.companies.create!(
      name: customer['company'].presence || "Perfex ##{userid}",
      additional_attributes: {
        'phonenumber' => customer['phonenumber'],
        'external' => { 'perfex_customer_id' => userid }
      }
    )
    existing_map[userid] = company
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Crm::Perfex company sync skipped for userid=#{customer['userid']}: #{e.message}"
    false
  end
end
