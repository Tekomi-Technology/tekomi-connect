class Crm::Perfex::MatchFromCacheJob < ApplicationJob
  queue_as :default

  def perform(contact_id)
    return if ENV['EXTERNAL_TICKET_SYSTEM_URL'].blank? || ENV['EXTERNAL_TICKET_SYSTEM_API_KEY'].blank?

    contact = Contact.find_by(id: contact_id)
    return if contact.nil? || contact.additional_attributes.dig('external', 'perfex_contact_id').present?

    contact_client = Crm::Perfex::Api::ContactClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    cached = Crm::Perfex::DirectoryCacheService.new(contact_client).peek
    return if cached.blank?

    customer_client = Crm::Perfex::Api::CustomerClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    Crm::Perfex::ContactMatcherService.new(contact_client: contact_client, customer_client: customer_client)
                                       .match_one(contact, cached)
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::MatchFromCacheJob failed for contact #{contact_id}: #{e.message}"
  end
end
