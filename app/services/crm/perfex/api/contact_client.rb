class Crm::Perfex::Api::ContactClient < Crm::Perfex::Api::BaseClient
  PER_PAGE = 20

  def fetch_all_contacts
    contacts = []
    page = 1

    loop do
      response = get('contacts', { page: page, per_page: PER_PAGE })
      batch = response['data'] || []
      contacts.concat(batch)

      total = response.dig('meta', 'total').to_i
      break if batch.empty? || contacts.size >= total

      page += 1
    end

    contacts
  end
end
