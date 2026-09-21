class Tekomi::Tools::Deals::GetDealService < Tekomi::Tools::BaseTool
  CONVERSATION_TOKEN_LIMIT = 2000
  ACTIVITY_LIMIT = 20

  def self.name
    'get_deal'
  end

  description 'Get the full details of a single deal, including the conversations linked to it and its change history'
  param :deal_id, type: :integer, desc: 'The ID of the deal'
  param :include_conversations, type: :string, desc: 'Set to "true" to include the transcript of the linked conversations'

  def execute(deal_id:, include_conversations: nil)
    deal = Deal.find_by(id: deal_id, account_id: @assistant.account_id)
    return 'Deal not found' if deal.blank?

    sections = [deal.to_llm_text]
    sections << "Change history:\n#{build_activities(deal)}"
    sections << "Linked conversations:\n#{build_conversations(deal, include_conversations)}"
    sections.join("\n---\n")
  end

  def active?
    user_has_permission('contact_manage')
  end

  private

  def build_activities(deal)
    activities = deal.activities.includes(:actor).limit(ACTIVITY_LIMIT)
    return 'No changes recorded for this deal' if activities.empty?

    activities.map do |activity|
      actor = activity.actor&.name || 'System'
      "- #{activity.created_at}: #{actor} #{activity.action} #{activity.metadata.to_json}"
    end.join("\n")
  end

  def build_conversations(deal, include_conversations)
    conversations = accessible_conversations(deal)
    return 'No conversations linked to this deal' if conversations.empty?

    return conversations.map { |conversation| "- Conversation ##{conversation.display_id} (#{conversation.status})" }.join("\n") unless
      include_conversations.to_s == 'true'

    conversations.map { |conversation| conversation.to_llm_text(token_limit: CONVERSATION_TOKEN_LIMIT) }.join("\n---\n")
  end

  def accessible_conversations(deal)
    conversations = deal.conversations.includes(:inbox, :contact)
    ::Conversations::PermissionFilterService.new(conversations, @user, deal.account).perform
  end
end
