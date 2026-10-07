class Api::V1::Accounts::Tekomi::PreferencesController < Api::V1::Accounts::BaseController
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    update_features if params[:tekomi_features]
    update_llm_provider if params[:llm_provider]
    update_llm_default if params[:llm_default]
    update_feature_models if params[:llm_feature_models]
    update_prompts if params[:tekomi_prompts]

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
    attributes = params.require(:llm_provider).permit(:provider_type, :api_key, :api_base, :remove)
    provider_type = attributes.fetch(:provider_type)
    raise ActiveRecord::RecordNotFound unless Llm::Providers.type?(provider_type) || Llm::Services.type?(provider_type)

    account_provider = @current_account.account_llm_providers.find_by(provider_type: provider_type)
    return account_provider&.destroy! if ActiveModel::Type::Boolean.new.cast(attributes[:remove])

    account_provider ||= @current_account.account_llm_providers.build(provider_type: provider_type)
    account_provider.api_key = attributes[:api_key] if attributes[:api_key].present?
    account_provider.api_base = attributes[:api_base].presence if attributes.key?(:api_base)
    account_provider.save!
  end

  def update_llm_default
    attributes = params.require(:llm_default).permit(:provider_type, :model)
    @current_account.llm_default_provider_type = attributes[:provider_type].presence
    @current_account.llm_default_model = attributes[:model].to_s.strip.presence
    @current_account.save!
  end

  def update_feature_models
    permitted_feature_models.each do |feature_key, attributes|
      feature_model = @current_account.account_llm_feature_models.find_or_initialize_by(feature_key: feature_key)

      if ActiveModel::Type::Boolean.new.cast(attributes[:remove])
        feature_model.destroy! if feature_model.persisted?
        next
      end

      feature_model.update!(attributes.except(:remove))
    end
  end

  def permitted_feature_models
    params.require(:llm_feature_models)
          .permit(Llm::Features.configurable_keys.index_with { [:provider_type, :model, :reasoning, :remove, { params: {} }] })
          .to_h
          .stringify_keys
  end

  def update_prompts
    permitted_prompts.each do |key, body|
      prompt = @current_account.account_llm_prompt_templates.find_or_initialize_by(key: key)
      normalized_body = body.to_s.gsub("\r\n", "\n")

      if normalized_body.blank? || normalized_body == Llm::Prompts.default_body(key)
        prompt.destroy! if prompt.persisted?
        next
      end

      prompt.body = normalized_body
      prompt.save!
    end
  end

  def permitted_prompts
    params.require(:tekomi_prompts).permit(Llm::Prompts.keys).to_h.stringify_keys
  end

  def preferences_payload
    payload = { features: @current_account.tekomi_preferences[:features].transform_values { |enabled| { enabled: enabled } } }
    return payload unless policy(@current_account).update?

    payload.merge(
      llm_providers: llm_providers_payload,
      llm_services: llm_services_payload,
      llm_default: { provider_type: @current_account.llm_default_provider_type, model: @current_account.llm_default_model },
      llm_feature_models: feature_models_payload,
      llm_models: Llm::ModelCatalog.grouped_by_provider,
      prompts: prompts_payload
    )
  end

  def llm_providers_payload
    account_providers = @current_account.account_llm_providers.index_by(&:provider_type)

    Llm::Providers.types.map do |provider_type|
      account_provider = account_providers[provider_type]
      {
        name: Llm::Providers.label(provider_type),
        provider_type: provider_type,
        requires_api_base: Llm::Providers.requires_api_base?(provider_type),
        supports_api_base: RubyLLM.config.respond_to?("#{provider_type}_api_base="),
        supports_reasoning: Llm::Providers.supports_reasoning?(provider_type),
        configured: account_provider.present?,
        api_base: account_provider&.api_base,
        masked_api_key: account_provider&.masked_api_key
      }
    end
  end

  def llm_services_payload
    account_providers = @current_account.account_llm_providers.index_by(&:provider_type)

    Llm::Services.types.map do |service_type|
      account_provider = account_providers[service_type]
      {
        name: Llm::Services.label(service_type),
        provider_type: service_type,
        requires_api_base: false,
        supports_api_base: false,
        configured: account_provider.present?,
        masked_api_key: account_provider&.masked_api_key
      }
    end
  end

  def feature_models_payload
    overrides = @current_account.account_llm_feature_models.index_by(&:feature_key)

    Llm::Features.configurable_keys.map do |feature_key|
      override = overrides[feature_key]
      {
        feature_key: feature_key,
        group: Llm::Features.group(feature_key),
        name: I18n.t("llm.features.#{feature_key}.name", default: feature_key.humanize),
        description: I18n.t("llm.features.#{feature_key}.description", default: ''),
        suggested_model: Llm::Features.suggested_model(feature_key),
        provider_type: override&.provider_type,
        model: override&.model,
        reasoning: override&.reasoning,
        params: override&.params || {},
        customized: override.present?
      }
    end
  end

  def prompts_payload
    overrides = @current_account.account_llm_prompt_templates.index_by(&:key)

    Llm::Prompts.grouped.flat_map do |group, prompt_keys|
      prompt_keys.map do |key|
        override = overrides[key]
        {
          key: key,
          group: group,
          name: I18n.t("llm.prompts.#{key}.name", default: key.humanize),
          description: I18n.t("llm.prompts.#{key}.description", default: ''),
          body: override&.body || Llm::Prompts.body(key, account: @current_account),
          default_body: Llm::Prompts.default_body(key),
          customized: override.present?
        }
      end
    end
  end
end
