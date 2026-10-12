class Api::V1::Accounts::Tekomi::PromptsController < Api::V1::Accounts::BaseController
  before_action :authorize_account_update
  before_action :fetch_prompt_key, only: [:show, :update, :destroy]

  def index
    overrides = @current_account.account_llm_prompt_templates.index_by(&:key)

    prompts = Llm::Prompts.grouped.flat_map do |group, keys|
      keys.map { |key| summary_payload(key, group, overrides[key]) }
    end

    render json: prompts
  end

  def show
    render json: detail_payload
  end

  def update
    body = params[:body].to_s.gsub("\r\n", "\n")
    prompt = @current_account.account_llm_prompt_templates.find_or_initialize_by(key: @prompt_key)

    if body.blank? || body == Llm::Prompts.default_body(@prompt_key)
      prompt.destroy! if prompt.persisted?
    else
      prompt.update!(body: body)
    end

    render json: detail_payload
  end

  def destroy
    @current_account.account_llm_prompt_templates.find_by(key: @prompt_key)&.destroy!

    render json: detail_payload
  end

  private

  def authorize_account_update
    authorize @current_account, :update?
  end

  def fetch_prompt_key
    @prompt_key = params[:key].to_s
    raise ActiveRecord::RecordNotFound unless Llm::Prompts.key?(@prompt_key)
  end

  def summary_payload(key, group, override)
    {
      key: key,
      group: group,
      name: I18n.t("llm.prompts.#{key}.name", default: key.humanize),
      description: I18n.t("llm.prompts.#{key}.description", default: ''),
      customized: override.present?,
      lines: (override&.body || Llm::Prompts.default_body(key)).lines.size
    }
  end

  def detail_payload
    override = @current_account.account_llm_prompt_templates.find_by(key: @prompt_key)
    default_body = Llm::Prompts.default_body(@prompt_key)

    {
      key: @prompt_key,
      group: Llm::Prompts.group(@prompt_key),
      name: I18n.t("llm.prompts.#{@prompt_key}.name", default: @prompt_key.humanize),
      description: I18n.t("llm.prompts.#{@prompt_key}.description", default: ''),
      customized: override.present?,
      body: override&.body || default_body,
      default_body: default_body
    }
  end
end
