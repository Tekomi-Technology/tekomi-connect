class Api::V1::Accounts::ConversationEmotionReportsController < Api::V1::Accounts::BaseController
  before_action :report, only: :update

  def index
    reports = permitted_reports.includes(:conversation, :contact, :inbox, :assignee)
    reports = reports.where(status: params[:status]) if params[:status].present?
    reports = reports.where(emotion: ConversationEmotionReport.emotion_filter_values(params[:emotion])) if params[:emotion].present?
    reports = reports.where(action_status: params[:action_status]) if params[:action_status].present?
    reports = reports.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    reports = reports.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    reports = reports.where('conversation_emotion_reports.resolved_at >= ?', Time.zone.at(params[:since].to_i)) if params[:since].present?

    total = reports.count
    page = [params.fetch(:page, 1).to_i, 1].max
    limit = params.fetch(:limit, 50).to_i.clamp(1, 100)
    reports = reports.order(resolved_at: :desc, id: :desc).offset((page - 1) * limit).limit(limit)

    render json: {
      data: reports.map(&:report_data),
      counts: report_counts,
      meta: {
        current_page: page,
        per_page: limit,
        total_entries: total,
        total_pages: (total.to_f / limit).ceil
      }
    }
  end

  def update
    @report.update!(params.require(:conversation_emotion_report).permit(:action_status))
    render json: @report.report_data
  end

  private

  def permitted_reports
    conversations = Conversations::PermissionFilterService.new(Current.account.conversations, Current.user, Current.account).perform
    Current.account.conversation_emotion_reports.where(conversation: conversations)
  end

  def report
    @report = permitted_reports.includes(:conversation, :contact, :inbox, :assignee).find(params[:id])
  end

  def report_counts
    reports = permitted_reports
    raw_emotions = reports.group(:emotion).count
    {
      total: reports.count,
      emotion: raw_emotions.each_with_object(Hash.new(0)) do |(emotion, count), normalized|
        next if emotion.blank?

        normalized[ConversationEmotionReport.normalize_emotion_label(emotion)] += count
      end,
      report_status: reports.group(:status).count,
      action_status: reports.group(:action_status).count
    }
  end
end
