class Tekomi::Deals::AssistantService < Llm::BaseAiService
  include Tekomi::ChatHelper

  attr_reader :assistant, :account, :user, :messages

  def initialize(assistant, config)
    super(feature: 'deal_assistant')

    @assistant = assistant
    @account = assistant.account
    @user = @account.users.find_by(id: config[:user_id])
    @previous_history = config[:previous_history].presence || []
    @deal = @account.deals.find_by(id: config[:deal_id]) if config[:deal_id].present?
    @pipeline = @account.pipelines.find_by(id: config[:pipeline_id]) if config[:pipeline_id].present?
    @tools = build_tools
    @messages = build_messages
  end

  def generate_response(input)
    @messages << { role: 'user', content: input } if input.present?
    response = request_chat_completion
    @account.increment_response_usage

    response
  end

  private

  def build_tools
    [
      Tekomi::Tools::Deals::SearchDealsService.new(@assistant, user: @user),
      Tekomi::Tools::Deals::GetDealService.new(@assistant, user: @user),
      Tekomi::Tools::Deals::DealStatsService.new(@assistant, user: @user)
    ].select(&:active?)
  end

  def build_messages
    messages = [system_message, account_context]
    messages += @previous_history
    messages += viewing_context
    messages
  end

  def system_message
    {
      role: 'system',
      content: Tekomi::Llm::SystemPromptsService.deal_assistant(tools_summary)
    }
  end

  def tools_summary
    @tools.map { |tool| "- #{tool.class.name}: #{tool.class.description}" }.join("\n")
  end

  def account_context
    {
      role: 'system',
      content: <<~CONTEXT.strip
        The current account id is #{@account.id}.
        The account is using #{@account.locale_english_name} as the language.
        Today is #{Time.zone.today}.
      CONTEXT
    }
  end

  def viewing_context
    return [] if @deal.blank? && @pipeline.blank?

    [{ role: 'system', content: "The user is currently looking at:\n#{viewing_details}" }]
  end

  def viewing_details
    return "Deal ID: ##{@deal.id} in pipeline #{@deal.pipeline.name}" if @deal.present?

    "Pipeline: #{@pipeline.name} (Pipeline ID: ##{@pipeline.id})"
  end

  def persist_message(message, message_type = 'assistant'); end

  def feature_name
    'deal_assistant'
  end
end
