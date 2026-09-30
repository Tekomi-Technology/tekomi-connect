namespace :phone_calls do
  desc 'Queue automatic emotion reports for terminal calls with recordings'
  task enqueue_emotion_analysis: :environment do
    scope = PhoneCall.where(status: PhoneCall::TERMINAL_STATUSES)
                     .where("metadata ? 'pbx_recording_url' OR metadata ? 'callytics_recording_resource'")
    queued = 0
    scope.find_each do |phone_call|
      Phone::CallEmotionAnalysisJob.perform_later(phone_call.id)
      queued += 1
    end
    puts "Queued #{queued} phone-call emotion reports"
  end
end
