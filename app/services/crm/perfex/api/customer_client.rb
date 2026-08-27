class Crm::Perfex::Api::CustomerClient < Crm::Perfex::Api::BaseClient
  PER_PAGE = 20

  def show(userid)
    get("customers/#{userid}")
  end

  def fetch_all_customers
    customers = []
    page = 1

    loop do
      response = get('customers', { page: page, per_page: PER_PAGE })
      batch = response['data'] || []
      customers.concat(batch)

      total = response.dig('meta', 'total').to_i
      break if batch.empty? || customers.size >= total

      page += 1
    end

    customers
  end
end
