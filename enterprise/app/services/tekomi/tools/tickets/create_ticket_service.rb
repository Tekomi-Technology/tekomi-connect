## Lets the chatbot open a support ticket from the conversation it is handling.
## The contact always comes from the conversation rather than the model, so the ticket
## cannot end up attached to whoever the customer happens to mention.
class Tekomi::Tools::Tickets::CreateTicketService < Tekomi::Tools::BaseTool
  def self.name
    'create_ticket'
  end

  description 'Open a support ticket for the customer in this conversation when they report an issue that needs ' \
              'follow-up work. Use it only for real service requests, never for questions you already answered.'
  param :title, type: :string, desc: 'A short summary of the issue, in the language the customer used'
  param :description, type: :string, desc: 'What the customer reported, including any detail needed to work on it'

  def initialize(assistant, user: nil, conversation: nil)
    @conversation = conversation
    super(assistant, user: user)
  end

  def execute(title:, description: nil)
    ticket = create_ticket(title, description)
    "Ticket ##{ticket.id} created in stage #{ticket.stage.name}"
  end

  def active?
    @conversation.present? && account.feature_enabled?('crm_tickets') && pipeline.present?
  end

  private

  def account
    @assistant.account
  end

  def pipeline
    @pipeline ||= account.pipelines.pipeline_type_ticket.order(:position, :id).first
  end

  # The conversation is linked too, so whoever picks the ticket up can read what the
  # customer actually said rather than only the summary the model wrote.
  def create_ticket(title, description)
    ticket = account.tickets.create!(
      pipeline: pipeline,
      stage: pipeline.stages.first,
      title: title.to_s.strip,
      description: description.presence,
      contact: @conversation.contact,
      created_by: :ai_chatbot
    )
    ticket.ticket_conversations.create!(conversation: @conversation)
    ticket
  end
end
