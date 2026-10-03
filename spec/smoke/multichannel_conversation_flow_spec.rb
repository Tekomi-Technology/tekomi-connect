require 'rails_helper'

# Smoke test for the conversation workstream: 20 conversations across the seven main channels,
# driven through each channel's real entry point (webhook job, mailbox, widget API, PBX event).
# It replays the faults that used to lose messages or desync state — duplicate deliveries, a
# failed attachment download, a channel that keeps failing on send, a customer writing again
# after resolve — and then checks the invariants the workstream promises:
#   * every inbound message is stored exactly once
#   * every agent reply ends up either delivered (has a channel id) or visibly failed
#   * a contact never has two unresolved conversations in the same inbox
RSpec.describe 'Multi-channel conversation flow smoke test', type: :request do
  include ActionMailbox::TestHelper

  before do
    stub_request(:any, /api.telegram.org/).to_return(status: 200, headers: { content_type: 'application/json' }, body: { ok: true }.to_json)
    stub_request(:post, /api.telegram.org.*sendMessage/)
      .to_return(status: 200, headers: { content_type: 'application/json' }, body: { ok: true, result: { message_id: 9001 } }.to_json)
    stub_request(:any, /graph.facebook.com/)
      .to_return(status: 200, headers: { content_type: 'application/json' }, body: { message_id: 'm_out_smoke' }.to_json)
    stub_request(:post, ZaloOa::MessageSender::MESSAGE_URL)
      .to_return(status: 200, headers: { content_type: 'application/json' }, body: { error: 0, data: { message_id: 'oa-out' } }.to_json)
    stub_request(:get, image_url).to_return(status: 200, body: File.read('spec/assets/sample.png'), headers: { content_type: 'image/png' })
    stub_request(:get, expired_url).to_return(status: 404)

    fb_api = instance_double(Koala::Facebook::API, get_object: { 'first_name' => 'Lan', 'last_name' => 'Pham' })
    allow(Koala::Facebook::API).to receive(:new).and_return(fb_api)
    # The gem signs Send API calls with the app secret, which the test env does not configure.
    allow(Facebook::Messenger::Bot).to receive(:deliver).and_return({ message_id: 'm_out_smoke' }.to_json)
    allow(ZaloOa::Client).to receive(:fetch_user_profile).and_return({ name: 'Khach OA' })
    allow(Zalo::WorkerClient).to receive(:profile).and_return({ 'name' => 'Khach Zalo' })
    allow(Zalo::WorkerClient).to receive(:send_text) { |_channel_id, payload| "zp-out-#{payload[:idempotency_key]}" }
  end

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:image_url) { 'https://zalo-cdn.example.com/photo.png' }
  let(:expired_url) { 'https://zalo-cdn.example.com/expired.png' }
  # Inbound events find their channel by external id (OA id, page id, bot token, SIP domain),
  # so every channel must exist before the first event — and after the HTTP stubs above.
  let!(:zalo_oa_inbox) do
    channel = Channel::ZaloOa.create!(account: account, oa_id: 'oa-smoke', app_id: 'app', app_secret: 'secret',
                                      oa_secret_key: 'key', access_token: 'token', token_expires_at: 1.day.from_now)
    create(:inbox, account: account, channel: channel)
  end
  let!(:zalo_personal_inbox) do
    channel = Channel::ZaloPersonal.create!(account: account, zalo_uid: 'zp-smoke', credentials: '{}', status: 'connected')
    create(:inbox, account: account, channel: channel)
  end
  # The factory builds the page's inbox under an account of its own.
  let!(:facebook_inbox) do
    create(:channel_facebook_page, account: account, page_id: 'page-smoke').inbox.tap { |inbox| inbox.update!(account: account) }
  end
  let!(:telegram_inbox) { create(:channel_telegram, account: account).inbox }
  let!(:email_channel) { create(:channel_email, account: account) }
  let!(:widget_channel) { create(:channel_widget, account: account) }
  let!(:phone_inbox) { create(:channel_phone, account: account, sip_domain: 'pbx-smoke.tekomi.vn').inbox }

  def zalo_oa_event(user, msg_id, text: nil, image: nil)
    message = { msg_id: msg_id, text: text }
    message[:attachments] = [{ type: 'image', payload: { url: image } }] if image
    { event_name: image ? 'user_send_image' : 'user_send_text', sender: { id: user }, recipient: { id: 'oa-smoke' }, message: message }
  end

  def zalo_oa_receive(...)
    Webhooks::ZaloOaEventsJob.perform_now(zalo_oa_event(...).deep_stringify_keys)
  end

  def zalo_personal_receive(thread, msg_id, **event)
    Webhooks::ZaloPersonalEventsJob.perform_now(
      { event: 'message', channel_id: zalo_personal_inbox.channel.id, kind: 'user', thread_id: thread, msg_id: msg_id,
        sender_name: 'Khach Zalo', is_self: false, content: nil, media: nil }.merge(event)
    )
  end

  def facebook_receive(sender, mid, text)
    payload = { messaging: { sender: { id: sender }, recipient: { id: 'page-smoke' }, message: { mid: mid, text: text } } }
    Webhooks::FacebookEventsJob.perform_now(payload.to_json)
  end

  def telegram_receive(user, message_id, text)
    Webhooks::TelegramEventsJob.perform_now(
      {
        bot_token: telegram_inbox.channel.bot_token,
        telegram: { message: { message_id: message_id, date: Time.current.to_i, text: text,
                               from: { id: user, is_bot: false, first_name: "TG#{user}" }, chat: { id: user, type: 'private' } } }
      }.with_indifferent_access
    )
  end

  def email_receive(from, subject, message_id, in_reply_to: nil)
    receive_inbound_email_from_mail(from: from, to: email_channel.email, subject: subject, body: "Noi dung #{subject}") do |mail|
      mail.message_id = message_id
      mail.in_reply_to = in_reply_to if in_reply_to
    end
  end

  def widget_start(name, content)
    contact_inbox = create(:contact_inbox, contact: create(:contact, account: account, name: name), inbox: widget_channel.inbox)
    token = Widget::TokenService.new(payload: { source_id: contact_inbox.source_id, inbox_id: widget_channel.inbox.id }).generate_token
    post api_v1_widget_conversations_url,
         params: { website_token: widget_channel.website_token, message: { content: content } },
         headers: { 'X-Auth-Token' => token }, as: :json
    expect(response).to have_http_status(:success)
  end

  def phone_event(call_id, event, status, number, direction: 'inbound')
    Phone::PbxCallEventProcessor.new(payload: {
                                       event_id: "#{event}:#{call_id}", event: event, pbx_id: 'pbx-smoke',
                                       sip_domain: 'pbx-smoke.tekomi.vn', linked_id: call_id, pbx_call_id: call_id,
                                       direction: direction, business_direction: direction, from_number: number,
                                       to_number: '1002', customer_number: number, status: status,
                                       started_at: Time.current.iso8601
                                     }).perform
  end

  def reply(conversation, content)
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                     message_type: :outgoing, sender: agent, content: content)
  end

  def unresolved_per_contact_inbox
    Conversation.where(account: account).where.not(status: :resolved).reorder(nil).group(:contact_inbox_id).count
  end

  # One continuous scenario on purpose: each step builds on the state the previous ones left.
  it 'keeps 20 multi-channel conversations lossless and consistent' do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    # --- Zalo OA (4 conversations) ---------------------------------------------------------
    zalo_oa_receive('oa-u1', 'oa-m1', text: 'Xin chao')
    zalo_oa_receive('oa-u1', 'oa-m1', text: 'Xin chao') # webhook delivered twice
    zalo_oa_receive('oa-u2', 'oa-m2', image: image_url)
    zalo_oa_receive('oa-u3', 'oa-m3', image: expired_url) # CDN link already expired
    zalo_oa_receive('oa-u4', 'oa-m4', text: 'Toi can ho tro')
    zalo_oa_receive('oa-u4', 'oa-m5', text: 'Them thong tin')

    # --- Zalo personal (4 conversations) ---------------------------------------------------
    zalo_personal_receive('zp-u1', 'zp-m1', content: 'Chao shop')
    zalo_personal_receive('zp-u1', 'zp-m1', content: 'Chao shop') # worker retried after a timeout
    zalo_personal_receive('zp-u2', 'zp-m2', media: { type: 'image', url: image_url, filename: 'anh.png' })
    zalo_personal_receive('zp-u3', 'zp-m3', content: 'Xem anh', media: { type: 'image', url: expired_url })
    zalo_personal_receive('zp-g1', 'zp-m4', kind: 'group', content: 'Nhom hoi gia', sender_name: 'Minh')

    # --- Facebook (3 conversations) --------------------------------------------------------
    facebook_receive('fb-u1', 'fb-m1', 'Hello page')
    facebook_receive('fb-u1', 'fb-m1', 'Hello page') # Messenger redelivery
    facebook_receive('fb-u2', 'fb-m2', 'Gia bao nhieu?')
    facebook_receive('fb-u3', 'fb-m3', 'Con hang khong?')
    facebook_receive('fb-u3', 'fb-m4', 'Ship ve Ha Noi')

    # --- Telegram (3 conversations) --------------------------------------------------------
    telegram_receive(501, 1, 'Hi bot')
    telegram_receive(502, 2, 'Order status?')
    telegram_receive(503, 3, 'Need invoice')

    # --- Email (2 conversations, one threaded reply) --------------------------------------
    email_receive('an@example.com', 'Bao gia', '<mail-1@example.com>')
    email_receive('an@example.com', 'Re: Bao gia', '<mail-2@example.com>', in_reply_to: '<mail-1@example.com>')
    email_receive('binh@example.com', 'Hoa don', '<mail-3@example.com>')

    # --- Website widget (2 conversations) --------------------------------------------------
    widget_start('Khach web 1', 'Can tu van')
    widget_start('Khach web 2', 'Hoi ve bao hanh')

    # --- Phone (2 conversations, call events replayed) -----------------------------------
    phone_event('call-1', 'call.ringing', 'ringing', '0901000001')
    phone_event('call-1', 'call.ringing', 'ringing', '0901000001') # PBX resent the event
    phone_event('call-1', 'call.completed', 'completed', '0901000001')
    phone_event('call-2', 'call.ringing', 'ringing', '0901000002')
    phone_event('call-2', 'call.missed', 'missed', '0901000002')

    conversations = Conversation.where(account: account)
    expect(conversations.count).to eq(20), -> { "per channel: #{conversations.joins(:inbox).group('inboxes.channel_type').count}" }

    # Inbound: every message once, nothing dropped.
    inbound = Message.where(account: account, message_type: :incoming)
    duplicates = inbound.where.not(source_id: nil).reorder(nil).group(:inbox_id, :source_id).having('COUNT(*) > 1').count
    expect(duplicates).to be_empty
    expect(zalo_oa_inbox.messages.incoming.count).to eq(5)
    expect(zalo_personal_inbox.messages.incoming.count).to eq(4)
    expect(facebook_inbox.messages.incoming.count).to eq(4)
    expect(telegram_inbox.messages.incoming.count).to eq(3)
    expect(email_channel.inbox.messages.incoming.count).to eq(3)
    expect(email_channel.inbox.conversations.count).to eq(2)
    expect(PhoneCall.where(inbox: phone_inbox).pluck(:status)).to contain_exactly('completed', 'missed')

    # A failed download keeps the message and tells the agent where the file is.
    expect(zalo_oa_inbox.messages.find_by(source_id: 'oa-m3').content).to include(expired_url)
    zp_kept = zalo_personal_inbox.messages.find_by(source_id: 'zp-m3')
    expect(zp_kept.content).to include('Xem anh', expired_url)
    expect(zalo_oa_inbox.messages.find_by(source_id: 'oa-m2').attachments.count).to eq(1)

    # Outbound: an agent reply on every messaging channel goes out and is acknowledged.
    replies = conversations.where.not(inbox: phone_inbox).map { |conversation| reply(conversation, 'Da nhan, em ho tro ngay') }
    perform_enqueued_jobs(only: SendReplyJob)
    replies.each(&:reload)
    external = replies.reject { |m| m.inbox.web_widget? || m.inbox.email? }
    undelivered = external.reject { |m| m.source_id.present? && m.status != 'failed' }
    expect(undelivered.map { |m| [m.inbox.channel_type, m.status, m.external_error] }).to be_empty

    # A channel that keeps failing marks the reply failed instead of leaving it "sent".
    allow(Zalo::WorkerClient).to receive(:send_text).and_raise(Zalo::WorkerClient::Error, 'worker unavailable')
    stuck = perform_enqueued_jobs(only: SendReplyJob) { reply(zalo_personal_inbox.conversations.first, 'Tin gui khi worker loi') }
    expect(stuck.reload.status).to eq('failed')
    expect(stuck.external_error).to eq(I18n.t('errors.send_reply.failed'))

    # Resolve, then the customer writes again: one unresolved conversation per contact, never two.
    conversations.each { |conversation| conversation.update!(status: :resolved) }
    zalo_oa_receive('oa-u1', 'oa-m9', text: 'Cho hoi them')
    zalo_personal_receive('zp-u1', 'zp-m9', content: 'Shop oi')
    facebook_receive('fb-u1', 'fb-m9', 'Toi quay lai')
    telegram_receive(501, 9, 'Back again')
    expect(unresolved_per_contact_inbox.values).to all(eq(1))
    expect(unresolved_per_contact_inbox.size).to eq(4)
  end
end
