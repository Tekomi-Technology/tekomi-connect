class Api::V1::Accounts::Tekomi::DealFieldExtractionsController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled
  before_action :set_deal

  def create
    result = ::Tekomi::Llm::DealFieldExtractionService.new(
      account: Current.account,
      deal: @deal,
      conversations: accessible_conversations,
      definitions: definitions
    ).perform
    return render_could_not_create_error(result[:error]) if result[:error].present?

    render json: { payload: build_payload(result[:message]) }
  end

  private

  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('crm_deals_ai')
  end

  def set_deal
    @deal = Current.account.deals.find(params.require(:deal_id))
    authorize(@deal, :update?)
  end

  def definitions
    @definitions ||= Current.account.custom_attribute_definitions.with_attribute_model('deal_attribute')
  end

  def accessible_conversations
    ::Conversations::PermissionFilterService.new(
      @deal.conversations.includes(:inbox, :contact),
      Current.user,
      Current.account
    ).perform
  end

  def build_payload(message)
    definitions_by_key = definitions.index_by(&:attribute_key)

    Array(message['fields']).filter_map do |field|
      definition = definitions_by_key[field['attribute_key']]
      next if definition.blank? || field['value'].blank?

      {
        attribute_key: definition.attribute_key,
        display_name: definition.attribute_display_name,
        display_type: definition.attribute_display_type,
        value: field['value'],
        reason: field['reason']
      }
    end
  end
end
