class SuperAdmin::LlmPromptTemplatesController < SuperAdmin::EnterpriseBaseController
  before_action :set_prompt_template, only: [:edit, :update, :destroy]

  def index
    @customized_keys = LlmPromptTemplate.pluck(:key)
  end

  def edit
    @prompt_template.body ||= Llm::Prompts.default_body(@prompt_template.key)
  end

  def update
    body = params.require(:llm_prompt_template).fetch(:body, '').gsub("\r\n", "\n")
    return destroy if body == Llm::Prompts.default_body(@prompt_template.key)
    return render :edit, status: :unprocessable_entity unless @prompt_template.update(body: body)

    redirect_to super_admin_llm_prompt_templates_path, notice: I18n.t('super_admin.llm_prompt_templates.saved')
  end

  def destroy
    @prompt_template.destroy! if @prompt_template.persisted?
    redirect_to super_admin_llm_prompt_templates_path, notice: I18n.t('super_admin.llm_prompt_templates.restored')
  end

  private

  def set_prompt_template
    raise ActiveRecord::RecordNotFound unless Llm::Prompts.key?(params[:key])

    @prompt_template = LlmPromptTemplate.find_or_initialize_by(key: params[:key])
  end
end
