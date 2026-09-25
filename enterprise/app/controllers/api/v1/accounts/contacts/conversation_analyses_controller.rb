class Api::V1::Accounts::Contacts::ConversationAnalysesController < Api::V1::Accounts::Contacts::BaseController
  RECENT_LIMIT = 10

  def index
    conversations = Conversations::PermissionFilterService.new(@contact.conversations, Current.user, Current.account).perform
    @analyses = ConversationAnalysis.where(conversation: conversations)
                                    .includes(:conversation, :analyzed_by)
                                    .order(updated_at: :desc)
                                    .limit(RECENT_LIMIT)
  end
end
