class ConversationEmotionAnalysisJob < ApplicationJob
  queue_as :low

  PROCESSING_TTL = 30.minutes

  discard_on ActiveRecord::RecordNotFound

  def perform(conversation_id, target_message_id, resolved_at = nil)
    conversation = Conversation.includes(:account, :inbox, :contact, :assignee).find(conversation_id)
    return if conversation.inbox.channel_type == 'Channel::Phone'

    report = prepare_report(conversation, target_message_id, resolved_at)
    return unless report

    transcript = transcript_for(conversation, target_message_id)
    return mark_skipped(report, target_message_id) if transcript.blank?

    result = Phone::JevEmotionAnalysisService.new(transcript: transcript, account: conversation.account).perform
    persist_result(report, target_message_id, result)
  rescue Phone::JevEmotionAnalysisService::DecisionFailed,
         CustomExceptions::Llm::FeatureNotConfigured,
         CustomExceptions::Llm::TenantProviderNotConfigured => e
    mark_failed(report, target_message_id, e)
  rescue StandardError => e
    mark_failed(report, target_message_id, e)
    Rails.logger.error("Conversation emotion job failed conversation=#{conversation_id} target_message=#{target_message_id}: #{e.class}: #{e.message}")
  end

  private

  def prepare_report(conversation, target_message_id, resolved_at)
    report = ConversationEmotionReport.create_or_find_by!(conversation_id: conversation.id) do |new_report|
      new_report.assign_attributes(report_attributes(conversation))
    end

    should_process = false
    report.with_lock do
      return if report.analyzed_through_message_id.to_i >= target_message_id
      if report.processing_message_id.to_i >= target_message_id && report.updated_at > PROCESSING_TTL.ago
        return
      end

      report.update!(
        current_report_attributes(conversation).merge(
          status: 'processing',
          processing_message_id: target_message_id,
          resolved_at: resolved_at.presence || conversation.status_changed_at,
          error_message: nil
        )
      )
      should_process = true
    end
    should_process ? report : nil
  end

  def report_attributes(conversation)
    {
      account: conversation.account,
      inbox: conversation.inbox,
      contact: conversation.contact,
      assignee: conversation.assignee,
      action_status: 'none'
    }
  end

  def current_report_attributes(conversation)
    report_attributes(conversation).except(:action_status)
  end

  def transcript_for(conversation, target_message_id)
    messages = conversation.messages
                           .where(private: false, message_type: %i[incoming outgoing])
                           .where('id <= ?', target_message_id)
                           .order(:id)

    messages.filter_map do |message|
      content = message.content_for_llm.to_s.strip
      next if content.blank?

      role = message.incoming? ? 'Khách hàng' : 'Nhân viên/Bot'
      "#{role}: #{content}"
    end.join("\n")
  end

  def persist_result(report, target_message_id, result)
    report.with_lock do
      return unless report.processing_message_id == target_message_id

      report.update!(
        status: 'completed',
        processing_message_id: nil,
        analyzed_through_message_id: target_message_id,
        emotion: result.fetch('label'),
        confidence: result.fetch('confidence'),
        probabilities: result.fetch('probabilities'),
        reason: result.fetch('reason'),
        llm_model: result.fetch('model'),
        llm_provider: result.fetch('provider'),
        processed_at: Time.current,
        error_message: nil
      )
    end
  end

  def mark_skipped(report, target_message_id)
    report.with_lock do
      return unless report.processing_message_id == target_message_id

      report.update!(
        status: 'skipped',
        processing_message_id: nil,
        analyzed_through_message_id: target_message_id,
        processed_at: Time.current,
        error_message: nil
      )
    end
  end

  def mark_failed(report, target_message_id, error)
    return unless report

    report.with_lock do
      return unless report.processing_message_id == target_message_id

      report.update!(
        status: 'failed',
        processing_message_id: nil,
        error_message: error.message.truncate(1_000)
      )
    end
  end
end
