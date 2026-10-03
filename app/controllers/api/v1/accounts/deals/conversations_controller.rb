class Api::V1::Accounts::Deals::ConversationsController < Api::V1::Accounts::BaseController
  include CrmDealsFeatureConcern

  before_action :fetch_deal

  def index
    conversations = @deal.conversations.includes(:assignee, :contact, :inbox, :taggings)
    @conversations = Conversations::PermissionFilterService.new(conversations, Current.user, Current.account).perform
                                                            .order(last_activity_at: :desc)
  end

  def create
    conversation = Current.account.conversations.find_by!(display_id: params.require(:conversation_id))
    authorize conversation, :show?
    @deal.deal_conversations.create!(conversation: conversation)
    head :ok
  end

  def destroy
    @deal.deal_conversations.joins(:conversation).find_by!(conversations: { display_id: params[:id] }).destroy!
    head :ok
  end

  private

  def fetch_deal
    @deal = Current.account.deals.find(params[:deal_id])
    authorize @deal, action_name == 'index' ? :show? : :update?
  end
end
