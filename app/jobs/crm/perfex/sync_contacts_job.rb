class Crm::Perfex::SyncContactsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    contact_client = Crm::Perfex::Api::ContactClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    customer_client = Crm::Perfex::Api::CustomerClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    Crm::Perfex::DirectoryCacheService.new(contact_client).refresh!

    contacts = Contact.where("additional_attributes -> 'external' ->> 'perfex_contact_id' IS NULL")
    return if contacts.none?

    Crm::Perfex::ContactMatcherService.new(contact_client: contact_client, customer_client: customer_client).match_all(contacts)
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::SyncContactsJob failed: #{e.message}"
  end
end
