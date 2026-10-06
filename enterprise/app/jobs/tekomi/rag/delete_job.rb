class Tekomi::Rag::DeleteJob < ApplicationJob
  queue_as :low

  def perform(account_id:, record_type:, record_id:)
    account = Account.find(account_id)
    Tekomi::Rag::Client.new(account: account).delete(record_type: record_type, record_id: record_id)
  end
end
