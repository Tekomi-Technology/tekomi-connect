class Contacts::AutoMergeJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 2.seconds, attempts: 10

  def perform(contact_id)
    account_id = Contact.where(id: contact_id).pick(:account_id)
    return if account_id.blank?

    with_lock(format(::Redis::Alfred::CONTACT_AUTO_MERGE_MUTEX, account_id: account_id), 30.seconds) do
      # Looked up again under the lock: a merge that ran meanwhile may have removed this contact.
      contact = Contact.find_by(id: contact_id)
      Contacts::AutoMergeService.new(contact: contact).perform if contact
    end
  end
end
