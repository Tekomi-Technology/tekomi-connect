class Phone::CallEmotionAnalysisJob < ApplicationJob
  queue_as :low

  discard_on ActiveRecord::RecordNotFound

  def perform(phone_call_id)
    phone_call = PhoneCall.includes(:emotion_report).find(phone_call_id)
    return unless phone_call.terminal? && recording_available?(phone_call)

    report = prepare_report(phone_call)
    return unless report

    result = Phone::CallEmotionAnalysisService.new(phone_call).perform
    persist_result(phone_call, report, result)
  rescue Phone::PbxRecordingFetcher::RecordingUnavailable,
         Phone::OpenrouterTranscriptionService::TranscriptionFailed => e
    mark_failed(phone_call, report, e)
  rescue StandardError => e
    mark_failed(phone_call, report, e)
    Rails.logger.error("Phone emotion job failed phone_call=#{phone_call_id}: #{e.class}: #{e.message}")
  end

  private

  def prepare_report(phone_call)
    report = PhoneCallEmotionReport.create_or_find_by!(phone_call_id: phone_call.id) do |new_report|
      new_report.assign_attributes(
        account: phone_call.account,
        conversation: phone_call.conversation,
        inbox: phone_call.inbox,
        purpose: 'monitoring',
        action_status: 'none'
      )
    end

    report.with_lock do
      return if report.status == 'completed'
      return if report.status == 'processing' && report.updated_at > 30.minutes.ago

      report.update!(
        account: phone_call.account,
        conversation: phone_call.conversation,
        inbox: phone_call.inbox,
        status: 'processing',
        purpose: report.purpose.presence || 'monitoring',
        action_status: report.action_status.presence || 'none',
        error_message: nil
      )
    end
    report
  end

  def persist_result(phone_call, report, result)
    emotion = result['emotion'].to_s
    report.update!(
      status: 'completed',
      emotion: emotion,
      reason: result.dig('semantic_emotion', 'reason'),
      transcript: result['transcript'],
      asr_model: result['asr_model'],
      asr_provider: result['asr_provider'],
      asr_runtime: result['asr_runtime'],
      llm_model: result['llm_model'],
      llm_provider: result['llm_provider'],
      processed_at: Time.current,
      error_message: nil
    )

    analysis = result.merge(
      'report_id' => report.id,
      'emotion_tag' => report.emotion_tag
    )
    phone_call.update!(metadata: phone_call.metadata.merge('emotion_analysis' => analysis))
    refresh_message(phone_call)
  end

  def mark_failed(phone_call, report, error)
    return unless report

    report.update_columns(
      status: 'failed',
      error_message: error.message.truncate(1_000),
      updated_at: Time.current
    )
    refresh_message(phone_call) if phone_call
  end

  def recording_available?(phone_call)
    metadata = phone_call.metadata || {}
    metadata['pbx_recording_url'].present? || metadata['callytics_recording_resource'].present?
  end

  def refresh_message(phone_call)
    message = phone_call.message
    return unless message

    message.update!(content_attributes: { data: phone_call.message_data })
    message.reload.send_update_event
  end
end
