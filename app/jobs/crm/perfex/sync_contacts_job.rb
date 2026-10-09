class Crm::Perfex::SyncContactsJob < ApplicationJob
  queue_as :scheduled_jobs

  LOCK_KEY = 'crm:perfex:directory-sync:lock'.freeze
  LOCK_TTL = 15.minutes
  WATERMARK_KEY = 'crm:perfex:contact-watermark:%<account_id>s'.freeze

  # `full` re-syncs every CRM contact (updates existing ones too); `incremental` only
  # creates contacts whose CRM id is above the per-account watermark.
  def perform(mode = 'full')
    return unless Crm::Perfex::Config.configured?

    acquired = Redis::Alfred.set(LOCK_KEY, '1', nx: true, ex: LOCK_TTL)
    return unless acquired
    @lock_acquired = true

    contact_client = Crm::Perfex::Api::ContactClient.new(
      base_url: Crm::Perfex::Config.system_url,
      api_key: Crm::Perfex::Config.api_key
    )
    customer_client = Crm::Perfex::Api::CustomerClient.new(
      base_url: Crm::Perfex::Config.system_url,
      api_key: Crm::Perfex::Config.api_key
    )
    contacts_cache = Crm::Perfex::DirectoryCacheService.new(contact_client)
    contacts_cache.refresh!
    customers_cache = Crm::Perfex::CustomerDirectoryCacheService.new(customer_client)
    customers_cache.refresh!

    sync_companies(customers_cache)
    sync_contacts(contacts_cache, mode.to_s == 'incremental')

    contacts = Contact.where("additional_attributes -> 'external' ->> 'perfex_contact_id' IS NULL")
    return if contacts.none?

    Crm::Perfex::ContactMatcherService.new(contact_client: contact_client, customer_client: customer_client).match_all(contacts)
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::SyncContactsJob failed: #{e.message}"
  ensure
    Redis::Alfred.delete(LOCK_KEY) if @lock_acquired
  end

  private

  def sync_companies(customers_cache)
    customers = customers_cache.fetch_all
    Account.find_each do |account|
      Crm::Perfex::CompanySyncService.new(account).sync(customers)
    end
  end

  def sync_contacts(contacts_cache, incremental)
    perfex_contacts = contacts_cache.fetch_all
    max_id = perfex_contacts.map { |contact| contact['id'].to_i }.max
    Account.find_each do |account|
      batch = incremental ? perfex_contacts.select { |contact| contact['id'].to_i > watermark(account) } : perfex_contacts
      Crm::Perfex::ContactSyncService.new(account).sync(batch)
      Redis::Alfred.set(format(WATERMARK_KEY, account_id: account.id), max_id) if max_id
    end
  end

  def watermark(account)
    Redis::Alfred.get(format(WATERMARK_KEY, account_id: account.id)).to_i
  end
end
