require 'rails_helper'

RSpec.describe Crm::Perfex::ContactChannelUnmapper do
  subject(:unmap_channel) do
    described_class.new(account: account, contact: crm_contact, conversation: conversation).perform
  end

  let(:account) { create(:account) }
  let(:crm_contact) do
    create(
      :contact,
      account: account,
      name: 'CRM customer',
      additional_attributes: {
        external: { perfex_contact_id: '42' },
        crm: { name: 'CRM customer' }
      }
    )
  end
  let(:channel_inbox) { create(:inbox, account: account) }
  let(:contact_inbox) do
    create(:contact_inbox, contact: crm_contact, inbox: channel_inbox, source_id: 'facebook-user-123')
  end
  let!(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: channel_inbox,
      contact: crm_contact,
      contact_inbox: contact_inbox
    )
  end
  let!(:previous_conversation) do
    create(
      :conversation,
      account: account,
      inbox: channel_inbox,
      contact: crm_contact,
      contact_inbox: contact_inbox
    )
  end
  let!(:customer_message) do
    create(:message, account: account, inbox: channel_inbox, conversation: conversation, sender: crm_contact)
  end
  let!(:agent_message) do
    create(:message, account: account, inbox: channel_inbox, conversation: conversation, sender: create(:user, account: account))
  end
  let(:other_inbox) { create(:inbox, account: account) }
  let!(:other_contact_inbox) do
    create(:contact_inbox, contact: crm_contact, inbox: other_inbox, source_id: 'zalo-user-456')
  end
  let!(:other_conversation) do
    create(
      :conversation,
      account: account,
      inbox: other_inbox,
      contact: crm_contact,
      contact_inbox: other_contact_inbox
    )
  end

  it 'detaches only the selected channel identity and keeps the CRM contact intact' do
    detached_contact = unmap_channel

    expect(detached_contact).to be_persisted
    expect(detached_contact.name).to eq('facebook-user-123')
    expect(detached_contact.additional_attributes).to eq({})
    expect(contact_inbox.reload.contact).to eq(detached_contact)
    expect(conversation.reload.contact).to eq(detached_contact)
    expect(previous_conversation.reload.contact).to eq(detached_contact)
    expect(customer_message.reload.sender).to eq(detached_contact)
    expect(agent_message.reload.sender).not_to eq(detached_contact)

    expect(crm_contact.reload).to be_persisted
    expect(other_contact_inbox.reload.contact).to eq(crm_contact)
    expect(other_conversation.reload.contact).to eq(crm_contact)
    expect(crm_contact.additional_attributes.dig('external', 'perfex_contact_id')).to eq('42')
  end

  it 'rejects a conversation belonging to another contact' do
    other_contact = create(:contact, account: account)
    other_contact_inbox = create(:contact_inbox, contact: other_contact, inbox: channel_inbox)
    foreign_conversation = create(
      :conversation,
      account: account,
      inbox: channel_inbox,
      contact: other_contact,
      contact_inbox: other_contact_inbox
    )

    expect do
      described_class.new(account: account, contact: crm_contact, conversation: foreign_conversation).perform
    end.to raise_error(described_class::UnmapError, 'Conversation does not belong to this contact')
  end
end
