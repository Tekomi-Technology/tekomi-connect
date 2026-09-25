class Crm::Perfex::MatchFromCacheJob < ApplicationJob
  queue_as :default

  def perform(contact_id)
    return unless Crm::Perfex::Config.configured?

    contact = Contact.find_by(id: contact_id)
    return if contact.nil? || contact.additional_attributes.dig('external', 'perfex_contact_id').present?

    contact_client = Crm::Perfex::Api::ContactClient.new(
      base_url: Crm::Perfex::Config.system_url,
      api_key: Crm::Perfex::Config.api_key
    )
    cached = Crm::Perfex::DirectoryCacheService.new(contact_client).peek
    return if cached.blank?

    customer_client = Crm::Perfex::Api::CustomerClient.new(
      base_url: Crm::Perfex::Config.system_url,
      api_key: Crm::Perfex::Config.api_key
    )
    Crm::Perfex::ContactMatcherService.new(contact_client: contact_client, customer_client: customer_client)
                                       .match_one(contact, cached)
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::MatchFromCacheJob failed for contact #{contact_id}: #{e.message}"
  end
end
