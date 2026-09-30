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
  EMOTION_ALIASES = {
    'buon' => 'buồn',
    'sad' => 'buồn',
    'tieu cuc' => 'buồn',
    'trung tinh' => 'trung tính',
    'trung' => 'trung tính',
    'neutral' => 'trung tính',
    'vui ve' => 'vui',
    'tich cuc' => 'vui',
    'happy' => 'vui',
    'positive' => 'vui',
    'kho' => 'khó chịu',
    'chiu' => 'khó chịu',
    'kho chiu' => 'khó chịu',
    'khong hai long' => 'khó chịu',
    'buc boi' => 'khó chịu',
    'frustrated' => 'khó chịu',
    'dissatisfied' => 'khó chịu',
    'annoyed' => 'khó chịu',
    'gay gat' => 'gay gắt',
    'gay' => 'gay gắt',
    'gat' => 'gay gắt',
    'tuc gian' => 'gay gắt',
    'angry' => 'gay gắt',
    'aggressive' => 'gay gắt'
  }.freeze
  LEGACY_STORED_LABELS = {
    'trung tính' => ['trung'],
    'khó chịu' => ['khó', 'chịu'],
    'gay gắt' => ['gay', 'gắt']
  }.freeze

  belongs_to :phone_call
  belongs_to :account
  belongs_to :conversation
  belongs_to :inbox

  validates :status, inclusion: { in: STATUSES }
  validates :action_status, inclusion: { in: ACTION_STATUSES }
  validates :purpose, inclusion: { in: PURPOSES }

  before_validation :normalize_emotion
  before_validation :set_emotion_color

  def self.normalize_emotion_label(value)
    label = value.to_s.unicode_normalize(:nfkc).strip.downcase.gsub(/[[:space:]]+/, ' ')
    return if label.blank?
    return label if EMOTION_COLORS.key?(label)

    ascii_label = I18n.transliterate(label).gsub(/[^a-z\s]/, '').squish
    EMOTION_ALIASES.fetch(ascii_label, label)
  end

  def self.emotion_filter_values(value)
    canonical = normalize_emotion_label(value)
    ascii_aliases = EMOTION_ALIASES.filter_map { |alias_name, label| alias_name if label == canonical }
    [canonical, *ascii_aliases, *LEGACY_STORED_LABELS.fetch(canonical, [])].uniq
  end

  def emotion_tag
    return if emotion.blank?

    label = self.class.normalize_emotion_label(emotion)
    { 'label' => label, 'color' => EMOTION_COLORS.fetch(label, 'gray') }
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
      extension: phone_call.extension,
      call_status: phone_call.status,
      duration_seconds: phone_call.duration_seconds,
      started_at: phone_call.started_at&.iso8601,
      ended_at: phone_call.ended_at&.iso8601,
      status: status,
      purpose: purpose,
      action_status: action_status,
      emotion: self.class.normalize_emotion_label(emotion),
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

  def normalize_emotion
    self.emotion = self.class.normalize_emotion_label(emotion) if emotion.present?
  end

  def set_emotion_color
    self.emotion_color = EMOTION_COLORS.fetch(emotion.to_s, 'gray') if emotion.present?
  end
end
