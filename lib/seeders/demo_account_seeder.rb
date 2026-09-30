require 'active_support/testing/time_helpers'

class Seeders::DemoAccountSeeder
  include ActiveSupport::Testing::TimeHelpers

  MARKER = 'demo_seed'.freeze
  DEMO_WEBSITE_URL = 'https://demo.example.com'.freeze
  DATA_FILE = Rails.root.join('lib/seeders/demo_data/it_services.yml')
  CONVERSATION_COUNT = 48
  TODAY_OPEN_COUNT = 3
  TODAY_RESOLVED_COUNT = 3
  PAST_OPEN_RATIO = 0.15
  HISTORY_DAYS = 30
  BUSINESS_TIME_ZONE = 'Asia/Ho_Chi_Minh'.freeze

  class NullDispatcher
    def dispatch(*); end
  end

  def initialize(account:, data_file: DATA_FILE)
    @account = account
    @data = YAML.safe_load(File.read(data_file))
    @agents = account.users.to_a
    @analyst = account.administrators.first || @agents.first
  end

  def seed!
    raise 'Demo data already exists in this account. Run the clear task first.' if demo_contacts.exists?
    raise 'The account has no users to assign conversations to.' if @agents.empty?

    with_events_silenced do
      create_labels
      create_inboxes
      create_companies
      create_contacts
      create_conversations
    end
  ensure
    travel_back
  end

  def clear!
    conversation_ids = demo_conversations.pluck(:id)
    ticket_ids = TicketConversation.where(conversation_id: conversation_ids).pluck(:ticket_id)

    with_events_silenced do
      ReportingEvent.where(conversation_id: conversation_ids).delete_all
      CsatSurveyResponse.where(conversation_id: conversation_ids).delete_all
      ConversationAnalysis.where(conversation_id: conversation_ids).delete_all
      @account.tickets.where(id: ticket_ids).destroy_all
      demo_conversations.find_each(&:destroy!)
      demo_contacts.find_each(&:destroy!)
      demo_companies.find_each(&:destroy!)
      demo_inboxes.each(&:destroy!)
    end
  end

  private

  def with_events_silenced
    dispatcher = Rails.configuration.dispatcher
    Rails.configuration.dispatcher = NullDispatcher.new
    yield
  ensure
    Rails.configuration.dispatcher = dispatcher
  end

  def demo_contacts
    @account.contacts.where("contacts.additional_attributes ->> '#{MARKER}' = 'true'")
  end

  def demo_conversations
    @account.conversations.where("conversations.additional_attributes ->> '#{MARKER}' = 'true'")
  end

  def demo_companies
    @account.companies.where("companies.additional_attributes ->> '#{MARKER}' = 'true'")
  end

  def demo_inboxes
    @account.inboxes.includes(:channel).select do |inbox|
      channel = inbox.channel
      case channel
      when Channel::Api then channel.additional_attributes[MARKER] == true
      when Channel::WebWidget then channel.website_url == DEMO_WEBSITE_URL
      else false
      end
    end
  end

  def create_labels
    @data['labels'].each do |label|
      @account.labels.find_or_create_by!(title: label['title']) do |record|
        record.description = label['description']
        record.color = label['color']
        record.show_on_sidebar = true
      end
    end
  end

  def create_inboxes
    @inboxes = @data['inboxes'].map do |config|
      channel = if config['type'] == 'web_widget'
                  Channel::WebWidget.create!(account: @account, website_url: DEMO_WEBSITE_URL, continuity_via_email: false)
                else
                  Channel::Api.create!(account: @account, additional_attributes: { MARKER => true })
                end
      inbox = @account.inboxes.create!(name: config['name'], channel: channel, enable_auto_assignment: false)
      @agents.each { |agent| inbox.inbox_members.create!(user: agent) }
      inbox
    end
  end

  def create_companies
    @companies = @data['companies'].to_h do |company|
      record = @account.companies.create!(
        name: company['name'], description: company['description'], additional_attributes: { MARKER => true }
      )
      [company['name'], record]
    end
  end

  def create_contacts
    @contacts = @data['contacts'].map do |contact|
      @account.contacts.create!(
        name: contact['name'],
        phone_number: contact['phone'],
        vip: contact['vip'] || false,
        company: @companies[contact['company']],
        additional_attributes: { 'city' => contact['city'], 'company_name' => contact['company'], MARKER => true }.compact
      )
    end
  end

  def create_conversations
    schedule.each do |plan|
      script = @data['scripts'][plan[:index] % @data['scripts'].size]
      create_conversation(script, plan)
    end
  end

  def schedule
    today = Array.new(TODAY_OPEN_COUNT) { { day: 0, open: true } } +
            Array.new(TODAY_RESOLVED_COUNT) { { day: 0, open: false } }
    past = Array.new(CONVERSATION_COUNT - today.size) do
      { day: rand(1..HISTORY_DAYS), open: rand < PAST_OPEN_RATIO }
    end
    (past + today).sort_by { |plan| -plan[:day] }.each_with_index.map { |plan, index| plan.merge(index: index) }
  end

  def create_conversation(script, plan)
    contact = pick_contact(plan)
    inbox = @inboxes.sample
    messages = plan[:open] ? open_messages(script['messages']) : script['messages']
    started_at = start_time(plan[:day], messages.size)
    assignee = plan[:open] && rand < 0.3 ? nil : @agents.sample

    conversation = travel_to(started_at) do
      contact_inbox = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
      @account.conversations.create!(
        inbox: inbox, contact: contact, contact_inbox: contact_inbox, assignee: assignee,
        priority: script['priority'], additional_attributes: { MARKER => true }
      )
    end
    travel_to(started_at) { conversation.update_labels(script['labels']) } if script['labels'].present?

    finished_at = create_messages(conversation, messages, started_at, today: plan[:day].zero?)
    return if plan[:open]

    finish_conversation(conversation, script, finished_at)
  end

  def pick_contact(plan)
    vip_contacts = @contacts.select(&:vip)
    plan[:open] && vip_contacts.any? && rand < 0.5 ? vip_contacts.sample : @contacts.sample
  end

  def open_messages(messages)
    last_incoming = messages.rindex { |message| message['in'] }
    cut = [last_incoming, 2].min
    cut += 1 until messages[cut]['in']
    messages.first(cut + 1)
  end

  def start_time(day, message_count)
    return Time.current - (message_count * 6).minutes - rand(10..150).minutes if day.zero?

    day.days.ago.in_time_zone(BUSINESS_TIME_ZONE).change(hour: rand(8..16), min: rand(0..59))
  end

  def create_messages(conversation, messages, started_at, today:)
    time = started_at
    first_reply = true

    messages.each_with_index do |message, index|
      time += message_gap(message, today) unless index.zero?
      travel_to(time) do
        if message['in']
          create_message(conversation, :incoming, message['in'], conversation.contact)
        else
          reply = create_message(conversation, :outgoing, message['out'], conversation.assignee || @agents.sample)
          record_reply(reply, first_reply)
          first_reply = false
        end
      end
    end
    time
  end

  def message_gap(message, today)
    return rand(1..5).minutes if today

    message['in'] ? rand(3..45).minutes : rand(1..25).minutes
  end

  def create_message(conversation, message_type, content, sender)
    conversation.messages.create!(
      account: @account, inbox: conversation.inbox, message_type: message_type, content: content, sender: sender
    )
  end

  def record_reply(message, first_reply)
    listener = ReportingEventListener.instance
    if first_reply
      listener.first_reply_created(Events::Base.new('first_reply_created', Time.current, message: message, conversation: message.conversation))
    else
      waiting_since = message.conversation.messages.incoming.where(created_at: ...message.created_at).maximum(:created_at)
      listener.reply_created(
        Events::Base.new('reply_created', Time.current, message: message, conversation: message.conversation, waiting_since: waiting_since)
      )
    end
  end

  def finish_conversation(conversation, script, last_message_at)
    resolved_at = [last_message_at + rand(5..90).minutes, Time.current - 1.minute].min
    resolved_at = last_message_at + 1.minute if resolved_at <= last_message_at

    travel_to(resolved_at) do
      conversation.update_columns(
        status: Conversation.statuses[:resolved], waiting_since: nil, last_activity_at: resolved_at, updated_at: resolved_at
      )
      ReportingEventListener.instance.conversation_resolved(
        Events::Base.new('conversation_resolved', Time.current, conversation: conversation.reload)
      )
      create_csat(conversation, script['csat']) if script['csat']
      create_ticket(conversation, script['ticket']) if script['ticket']
      create_analysis(conversation, script['analysis']) if script['analysis']
    end
  end

  def create_csat(conversation, csat)
    response = { 'rating' => csat['rating'], 'feedback_message' => csat['feedback'].presence }.compact
    message = conversation.messages.create!(
      account: @account, inbox: conversation.inbox, message_type: :template, content_type: :input_csat,
      content: I18n.with_locale(@account.locale) { I18n.t('conversations.templates.csat_input_message_body') },
      content_attributes: { 'display_type' => 'emoji', 'submitted_values' => { 'csat_survey_response' => response } }
    )
    CsatSurveyResponse.create!(
      account: @account, conversation: conversation, contact: conversation.contact, message: message,
      rating: csat['rating'], feedback_message: csat['feedback'].presence, assigned_agent: conversation.assignee
    )
  end

  def create_ticket(conversation, ticket)
    record = @account.tickets.create!(
      stage: ticket_pipeline.stages.first, title: ticket['title'], description: ticket['description'],
      contact: conversation.contact, assignee: conversation.assignee, created_by: :staff
    )
    record.ticket_conversations.create!(conversation: conversation)
  end

  def ticket_pipeline
    @ticket_pipeline ||= @account.pipelines.pipeline_type_ticket.first ||
                         I18n.with_locale(@account.locale) do
                           @account.pipelines.create!(name: I18n.t('crm_tickets.default_pipeline.name'), pipeline_type: :ticket)
                         end
  end

  def create_analysis(conversation, analysis)
    ConversationAnalysis.create!(
      account: @account, conversation: conversation, contact: conversation.contact, inbox: conversation.inbox,
      assignee: conversation.assignee, analyzed_by: @analyst, served_by: analysis['served_by'],
      quality: analysis['quality'], customer: analysis['customer'], insight: analysis['insight'],
      conversation_state: analysis['conversation_state'], care: analysis['care'] || {},
      quality_score: ConversationAnalysis.quality_score_from(analysis['quality'])
    )
  end
end
