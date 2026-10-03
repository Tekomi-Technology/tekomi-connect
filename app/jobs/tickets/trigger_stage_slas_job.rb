class Tickets::TriggerStageSlasJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.feature_crm_tickets.find_each do |account|
      Tickets::ProcessAccountStageSlasJob.perform_later(account)
    end
  end
end
