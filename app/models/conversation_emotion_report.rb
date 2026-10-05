class ConversationEmotionReport < ApplicationRecord
  STATUSES = %w[pending processing completed failed skipped].freeze
  ACTION_STATUSES = PhoneCallEmotionReport::ACTION_STATUSES
  EMOTION_COLORS = PhoneCallEmotionReport::EMOTION_COLORS

  belongs_to :conversation
  belongs_to :account
  belongs_to :inbox
  belongs_to :contact
  belongs_to :assignee, class_name: 'User', optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :action_status, inclusion: { in: ACTION_STATUSES }

  before_validation :normalize_emotion
  before_validation :set_emotion_color

  def self.normalize_emotion_label(value)
    PhoneCallEmotionReport.normalize_emotion_label(value)
  end

  def self.emotion_filter_values(value)
    PhoneCallEmotionReport.emotion_filter_values(value)
  end

  def emotion_tag
    return if emotion.blank?

    label = self.class.normalize_emotion_label(emotion)
    { 'label' => label, 'color' => EMOTION_COLORS.fetch(label, 'gray') }
  end

  def report_data
    {
      id: id,
      conversation_id: conversation.display_id,
      conversation_record_id: conversation_id,
      account_id: account_id,
      inbox_id: inbox_id,
      inbox_name: inbox.name,
      channel_type: inbox.channel_type,
      contact_id: contact_id,
      contact_name: contact.name,
      assignee_id: assignee_id,
      assignee_name: assignee&.available_name,
      status: status,
      action_status: action_status,
      emotion: self.class.normalize_emotion_label(emotion),
      emotion_tag: emotion_tag,
      confidence: confidence,
      probabilities: probabilities,
      reason: reason,
      analyzed_through_message_id: analyzed_through_message_id,
      resolved_at: resolved_at&.iso8601,
      processed_at: processed_at&.iso8601,
      llm_model: llm_model,
      llm_provider: llm_provider,
      error_message: error_message,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }.compact
  end

  private

  def normalize_emotion
    self.emotion = self.class.normalize_emotion_label(emotion) if emotion.present?
  end

  def set_emotion_color
    self.emotion_color = EMOTION_COLORS.fetch(emotion.to_s, 'gray') if emotion.present?
  end
end
