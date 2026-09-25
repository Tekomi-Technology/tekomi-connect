class ConversationAnalyses::ReportService
  LOW_SCORE = 60
  LOW_SCORE_LIMIT = 20
  AGENT_SERVED = %w[agent both].freeze

  pattr_initialize [:analyses!]

  def perform
    {
      analyzed_count: analyses.count,
      average_score: average(analyses.average(:quality_score)),
      criteria: criteria_averages,
      served_by: served_by_breakdown,
      agents: agent_breakdown,
      low_scores: analyses.where('conversation_analyses.quality_score < ?', LOW_SCORE).order(:quality_score, updated_at: :desc)
                          .includes(:conversation, :contact, :assignee).limit(LOW_SCORE_LIMIT)
    }
  end

  private

  def criteria_averages
    ConversationAnalysis::CRITERIA.index_with do |criterion|
      score = Arel.sql("(conversation_analyses.quality -> '#{criterion}' ->> 'score')::int")
      average(analyses.where("#{score} > 0").average(score), 1)
    end
  end

  def served_by_breakdown
    analyses.group(:served_by).pluck(:served_by, Arel.sql('COUNT(*)'), Arel.sql('AVG(quality_score)')).map do |served_by, count, score|
      { served_by: served_by, count: count, average_score: average(score) }
    end
  end

  def agent_breakdown
    rows = analyses.where(served_by: AGENT_SERVED).where.not(assignee_id: nil).group(:assignee_id)
                   .pluck(:assignee_id, Arel.sql('COUNT(*)'), Arel.sql('AVG(quality_score)'))
    names = User.where(id: rows.map(&:first)).index_by(&:id)
    rows.map do |assignee_id, count, score|
      { id: assignee_id, name: names[assignee_id]&.available_name, count: count, average_score: average(score) }
    end.sort_by { |row| -row[:average_score].to_f }
  end

  def average(value, precision = 0)
    value&.to_f&.round(precision)
  end
end
