class PhoneCallEmotionReport < ApplicationRecord
  STATUSES = %w[pending processing completed failed skipped].freeze
  ACTION_STATUSES = %w[none needs_follow_up in_progress resolved].freeze
  PURPOSES = %w[monitoring follow_up quality_review].freeze
  EMOTION_COLORS = {
    'buồn' => 'purple',
    'trung tính' => 'green',
    'vui' => 'blue',
    'khó chịu' => 'orange',
    'gay gắt' => 'red'
  }.freeze

  belongs_to :phone_call
  belongs_to :account
  belongs_to :conversation
  belongs_to :inbox

  validates :status, inclusion: { in: STATUSES }
  validates :action_status, inclusion: { in: ACTION_STATUSES }
  validates :purpose, inclusion: { in: PURPOSES }

  before_validation :set_emotion_color

  def emotion_tag
    return if emotion.blank?

    { 'label' => emotion, 'color' => emotion_color || 'green' }
  end

  def report_data
    {
      id: id,
      phone_call_id: phone_call_id,
      account_id: account_id,
      conversation_id: conversation_id,
      inbox_id: inbox_id,
      direction: phone_call.direction,
      customer_number: phone_call.customer_number,
      status: status,
      purpose: purpose,
      action_status: action_status,
      emotion: emotion,
      emotion_tag: emotion_tag,
      reason: reason,
      transcript: transcript,
      asr_model: asr_model,
      asr_provider: asr_provider,
      asr_runtime: asr_runtime,
      llm_model: llm_model,
      llm_provider: llm_provider,
      error_message: error_message,
      processed_at: processed_at&.iso8601,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }.compact
  end

  private

  def set_emotion_color
    self.emotion_color = EMOTION_COLORS.fetch(emotion.to_s, 'green') if emotion.present?
  end
end
