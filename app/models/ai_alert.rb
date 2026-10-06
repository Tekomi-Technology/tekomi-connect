class AiAlert < ApplicationRecord
  CATEGORIES = %w[configuration authentication quota availability provider unknown].freeze

  belongs_to :account

  validates :category, inclusion: { in: CATEGORIES }
  validates :title, :message, :fingerprint, :last_seen_at, presence: true
  validates :occurrences, numericality: { only_integer: true, greater_than: 0 }

  scope :recent_first, -> { order(last_seen_at: :desc, id: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def push_event_data
    {
      id: id,
      account_id: account_id,
      category: category,
      feature: feature,
      provider: provider,
      title: title,
      message: message,
      status_code: status_code,
      metadata: metadata || {},
      occurrences: occurrences,
      last_seen_at: last_seen_at&.iso8601,
      read_at: read_at&.iso8601,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end
end
