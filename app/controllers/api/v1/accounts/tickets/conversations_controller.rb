class Api::V1::Accounts::Tickets::ConversationsController < Api::V1::Accounts::BaseController
  include CrmTicketsFeatureConcern

  before_action :fetch_ticket

  def index
    conversations = @ticket.conversations.includes(:assignee, :contact, :inbox, :taggings)
    @conversations = Conversations::PermissionFilterService.new(conversations, Current.user, Current.account).perform
                                                           .order(last_activity_at: :desc)
  end

  def create
    conversation = Current.account.conversations.find_by!(display_id: params.require(:conversation_id))
    authorize conversation, :show?
    @ticket.ticket_conversations.create!(conversation: conversation)
    head :ok
  end

  def destroy
    @ticket.ticket_conversations.joins(:conversation).find_by!(conversations: { display_id: params[:id] }).destroy!
    head :ok
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
    authorize @ticket, action_name == 'index' ? :show? : :update?
  end
end
