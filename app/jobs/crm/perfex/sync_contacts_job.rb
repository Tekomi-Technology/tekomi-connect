class Crm::Perfex::SyncContactsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    contacts = Contact.where("additional_attributes -> 'external' ->> 'perfex_contact_id' IS NULL")
    return if contacts.none?

    client = Crm::Perfex::Api::ContactClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    Crm::Perfex::ContactMatcherService.new(client).match_all(contacts)
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::SyncContactsJob failed: #{e.message}"
  end
end
