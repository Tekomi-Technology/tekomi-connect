class Api::V2::Accounts::TeamMonitoringController < Api::V1::Accounts::BaseController
  include DateRangeHelper

  before_action :check_authorization

  def index
    return head :unprocessable_entity if params[:since].blank? || params[:until].blank?

    render json: V2::Reports::TeamMonitoringBuilder.new(
      account: Current.account,
      teams: visible_teams,
      params: builder_params,
      include_ungrouped: Current.account_user.administrator?
    ).build
  end

  # Backs the row expansion: which customers an agent is handling right now.
  def agent_conversations
    return head :unprocessable_entity if params[:user_id].blank?
    return head :not_found unless visible_user_ids.include?(params[:user_id].to_i)

    render json: open_conversations_for(params[:user_id])
  end

  private

  def check_authorization
    authorize :team_monitoring, :view?
  end

  def visible_teams
    @visible_teams ||= if Current.account_user.administrator?
                         Current.account.teams.includes(:supervisor).order(:name)
                       else
                         Current.account.teams.includes(:supervisor).where(supervisor_id: Current.user.id).order(:name)
                       end
  end

  def visible_user_ids
    @visible_user_ids ||= if Current.account_user.administrator?
                            Current.account.account_users.pluck(:user_id)
                          else
                            TeamMember.where(team_id: visible_teams.map(&:id)).pluck(:user_id).uniq
                          end
  end

  def open_conversations_for(user_id)
    Current.account.conversations.open.where(assignee_id: user_id)
           .includes(:contact, :inbox).order(last_activity_at: :desc).limit(100)
           .map do |conversation|
      {
        id: conversation.display_id,
        contact_name: conversation.contact&.name.presence || conversation.contact&.email,
        contact_id: conversation.contact_id,
        inbox_name: conversation.inbox.name,
        last_activity_at: conversation.last_activity_at.to_i,
        waiting_since: conversation.waiting_since&.to_i
      }
    end
  end

  def builder_params
    {
      since: parse_date_time(params[:since]),
      until: parse_date_time(params[:until]),
      timezone_offset: params[:timezone_offset],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours])
    }
  end
end
