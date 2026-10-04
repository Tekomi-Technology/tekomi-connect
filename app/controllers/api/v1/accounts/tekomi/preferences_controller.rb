class Api::V1::Accounts::Tekomi::PreferencesController < Api::V1::Accounts::BaseController
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    update_features if params[:tekomi_features]
    update_llm_provider if params[:llm_provider]

    render json: preferences_payload
  end

  private

  def authorize_account_update
    authorize @current_account, :update?
  end

  def permitted_tekomi_features
    params.require(:tekomi_features).permit(*TekomiFeaturable::TOGGLE_FEATURE_KEYS).to_h.stringify_keys
  end

  def update_features
    @current_account.tekomi_features = (@current_account.tekomi_features || {}).merge(permitted_tekomi_features)
    @current_account.save!
  end

  def update_llm_provider
    attributes = params.require(:llm_provider).permit(:provider_type, :api_key, :use_global)
    provider_type = attributes.fetch(:provider_type)
    raise ActiveRecord::RecordNotFound unless LlmProvider.exists?(provider_type: provider_type)

    account_provider = @current_account.account_llm_providers.find_by(provider_type: provider_type)
    return account_provider&.destroy! if ActiveModel::Type::Boolean.new.cast(attributes[:use_global])

    account_provider ||= @current_account.account_llm_providers.build(provider_type: provider_type)
    account_provider.api_key = attributes[:api_key] if attributes[:api_key].present?
    account_provider.save!
  end

  def preferences_payload
    payload = { features: @current_account.tekomi_preferences[:features].transform_values { |enabled| { enabled: enabled } } }
    payload[:llm_providers] = llm_providers_payload if policy(@current_account).update?
    payload
  end

  def llm_providers_payload
    account_providers = @current_account.account_llm_providers.index_by(&:provider_type)
    LlmProvider.order(:name).map do |provider|
      account_provider = account_providers[provider.provider_type]
      {
        name: provider.name,
        provider_type: provider.provider_type,
        configured: account_provider.present?,
        masked_api_key: account_provider&.masked_api_key
      }
    end
  end
end
