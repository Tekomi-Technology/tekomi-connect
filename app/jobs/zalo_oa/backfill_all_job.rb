class ZaloOa::BackfillAllJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::ZaloOa.find_each { |channel| ZaloOa::BackfillJob.perform_later(channel.id) }
  end
end
