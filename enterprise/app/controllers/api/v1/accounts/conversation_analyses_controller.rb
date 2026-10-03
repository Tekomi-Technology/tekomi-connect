class Api::V1::Accounts::ConversationAnalysesController < Api::V1::Accounts::BaseController
  OPPORTUNITY_LEVELS = %w[high medium].freeze
  PER_PAGE = 25
  HIGH_INTEREST_FIRST = Arel.sql("CASE conversation_analyses.insight ->> 'interest_level' WHEN 'high' THEN 0 ELSE 1 END")

  def report
    @report = ConversationAnalyses::ReportService.new(analyses: filtered_analyses).perform
  end

  def opportunities
    levels = Array(params[:interest_levels]).presence || OPPORTUNITY_LEVELS
    @analyses = filtered_analyses.where("conversation_analyses.insight ->> 'interest_level' IN (?)", levels)
                                 .includes(:conversation, :contact, :assignee)
                                 .order(HIGH_INTEREST_FIRST, updated_at: :desc)
                                 .page(params[:page]).per(PER_PAGE)
  end

  private

  def filtered_analyses
    conversations = Conversations::PermissionFilterService.new(Current.account.conversations, Current.user, Current.account).perform
    analyses = Current.account.conversation_analyses.where(conversation: conversations)
                      .where(params.permit(:inbox_id, :assignee_id).compact_blank.to_h)
    return analyses if params[:since].blank?

    analyses.where(updated_at: Time.zone.at(params[:since].to_i)..)
  end
end
