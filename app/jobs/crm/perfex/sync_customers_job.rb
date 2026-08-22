class Crm::Perfex::SyncCustomersJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    contacts = Contact.where("additional_attributes -> 'external' ->> 'perfex_id' IS NULL")
    return if contacts.none?

    client = Crm::Perfex::Api::CustomerClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    Crm::Perfex::CustomerMatcherService.new(client).match_all(contacts)
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::SyncCustomersJob failed: #{e.message}"
  end
end
