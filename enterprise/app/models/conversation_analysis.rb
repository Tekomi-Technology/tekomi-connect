class ConversationAnalysis < ApplicationRecord
  CRITERIA = %w[understanding completeness accuracy tone resolution proactiveness].freeze
  SERVED_BY = %w[bot agent both none].freeze
  INTEREST_LEVELS = %w[high medium low unknown].freeze
  SENTIMENTS = %w[positive neutral concerned frustrated unknown].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :contact
  belongs_to :inbox
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :analyzed_by, class_name: 'User', optional: true

  validates :served_by, inclusion: { in: SERVED_BY }
  validate :criteria_scores_in_range

  def self.record!(conversation:, analyzed_by:, result:)
    analysis = find_or_initialize_by(conversation: conversation)
    analysis.update!(
      account: conversation.account,
      contact: conversation.contact,
      inbox: conversation.inbox,
      assignee: conversation.assignee,
      analyzed_by: analyzed_by,
      served_by: result['served_by'],
      quality: result['quality'],
      customer: result['customer'],
      insight: result['insight'],
      conversation_state: result['conversation_state'],
      care: {},
      quality_score: quality_score_from(result['quality'])
    )
    analysis
  end

  def self.quality_score_from(quality)
    scores = CRITERIA.map { |criterion| quality.dig(criterion, 'score').to_i }.select(&:positive?)
    return if scores.empty?

    (scores.sum * 20.0 / scores.size).round
  end

  private

  def criteria_scores_in_range
    return if CRITERIA.all? { |criterion| (0..5).cover?(quality.dig(criterion, 'score')) }

    errors.add(:quality, 'must score every criterion from 0 to 5')
  end
end
