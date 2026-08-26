require 'rails_helper'

RSpec.describe Phone::PbxCallEventProcessor do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:channel) { create(:channel_phone, account: account, sip_domain: 'td1.tekomi.vn') }
  let(:inbox) { channel.inbox }
  let!(:extension) do
    create(:phone_extension, account: account, inbox: inbox, user: agent, sip_username: '1002')
  end

  def process(overrides = {})
    payload = {
      event_id: 'call.ringing:leg-agent',
      event: 'call.ringing',
      pbx_id: 'td1',
      sip_domain: 'td1.tekomi.vn',
      pbx_call_id: 'linked-call-1',
      linked_id: 'linked-call-1',
      leg_uuid: 'leg-agent',
      direction: 'inbound',
      business_direction: 'outbound',
      from_number: '1002',
      to_number: '0342387314',
      customer_number: '0342387314',
      extension: '1002',
      status: 'ringing',
      started_at: '2026-08-25T15:24:00Z'
    }.merge(overrides)
    described_class.new(payload: payload).perform
  end

  it 'creates one outbound phone message on the right-side message semantics' do
    expect { process }.to change(PhoneCall, :count).by(1).and change(Message, :count).by(1)

    phone_call = PhoneCall.last
    message = phone_call.message
    expect(phone_call).to have_attributes(
      inbox: inbox,
      user: agent,
      phone_extension: extension,
      direction: 'outbound',
      customer_number: '+84342387314',
      status: 'ringing'
    )
    expect(message).to be_outgoing
    expect(message).to be_phone_call
    expect(message.sender).to eq(agent)
    expect(message.content_attributes.dig('data', 'direction')).to eq('outbound')
    expect(message.conversation.contact.phone_number).to eq('+84342387314')
  end

  it 'creates an inbound message authored by the contact' do
    process(
      event_id: 'call.ringing:leg-customer',
      pbx_call_id: 'linked-call-2',
      linked_id: 'linked-call-2',
      leg_uuid: 'leg-customer',
      business_direction: 'inbound',
      from_number: '0342387314',
      to_number: '1002'
    )

    phone_call = PhoneCall.last
    expect(phone_call.direction).to eq('inbound')
    expect(phone_call.message).to be_incoming
    expect(phone_call.message.sender).to eq(phone_call.contact)
  end

  it 'deduplicates an identical PBX event at the database boundary' do
    process

    expect { process }.not_to change { [PbxCallEvent.count, PhoneCall.count, Message.count] }
  end

  it 'merges another SIP leg and does not regress after a terminal event' do
    process
    process(
      event_id: 'call.answered:leg-carrier',
      event: 'call.answered',
      leg_uuid: 'leg-carrier',
      business_direction: nil,
      extension: nil,
      customer_number: nil,
      from_number: '02483801899',
      to_number: '0342387314',
      status: 'answered',
      answered_at: '2026-08-25T15:24:06Z'
    )
    process(
      event_id: 'call.completed:leg-carrier',
      event: 'call.completed',
      leg_uuid: 'leg-carrier',
      business_direction: nil,
      extension: nil,
      customer_number: nil,
      status: 'completed',
      ended_at: '2026-08-25T15:24:22Z',
      duration: 22,
      hangup_cause: 'NORMAL_CLEARING'
    )
    process(event_id: 'call.ringing:late-leg', leg_uuid: 'late-leg')

    phone_call = PhoneCall.last
    expect(phone_call).to have_attributes(status: 'completed', duration_seconds: 22, hangup_cause: 'NORMAL_CLEARING')
    expect(phone_call.message.content_attributes.dig('data', 'status')).to eq('completed')
    expect(PhoneCall.count).to eq(1)
    expect(Message.phone_calls.count).to eq(1)
  end

  it 'updates the existing bubble when a recording becomes available' do
    process
    process(
      event_id: 'call.completed:leg-agent',
      event: 'call.completed',
      status: 'completed',
      duration: 15
    )
    process(
      event_id: 'call.recording_ready:leg-agent',
      event: 'call.recording_ready',
      recording_url: 'https://recordings.example.com/call-1.wav'
    )

    phone_call = PhoneCall.last
    expect(phone_call.recording_url).to eq('https://recordings.example.com/call-1.wav')
    expect(phone_call.message.content_attributes.dig('data', 'recording_url')).to eq('https://recordings.example.com/call-1.wav')
    expect(Message.phone_calls.count).to eq(1)
  end

  it 'classifies an outbound busy hangup without creating another message' do
    process
    process(
      event_id: 'call.missed:leg-agent',
      event: 'call.missed',
      status: 'missed',
      hangup_cause: 'USER_BUSY'
    )

    expect(PhoneCall.last.status).to eq('busy')
    expect(Message.phone_calls.count).to eq(1)
  end
end
