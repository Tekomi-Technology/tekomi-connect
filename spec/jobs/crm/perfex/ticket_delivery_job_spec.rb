require 'rails_helper'

RSpec.describe Crm::Perfex::TicketDeliveryJob do
  include ActiveJob::TestHelper

  let(:ticket_client) { instance_double(Crm::Perfex::Api::TicketClient) }

  before do
    allow(Crm::Perfex::Api::TicketClient).to receive(:new).and_return(ticket_client)
    allow(ticket_client).to receive(:create_ticket).and_return('success' => true)
  end

  describe '#perform' do
    context 'when the contact is matched with the CRM' do
      let!(:account) { create(:account) }
      let!(:company) { create(:company, account: account, name: 'Acme Ltd') }
      let(:contact) do
        create(:contact, account: account,
                         additional_attributes: { 'external' => { 'perfex_contact_id' => '1', 'perfex_customer_id' => '10' } })
      end
      let(:conversation) { create(:conversation, account: account, contact: contact) }

      before { contact.update!(company: company) }

      it 'creates a ticket with CRM references and records the delivery' do
        allow(ticket_client).to receive(:create_ticket).and_return(
          'success' => true, 'data' => { 'ticketid' => 77 }
        )

        with_modified_env(EXTERNAL_TICKET_SYSTEM_URL: 'https://crm.techxanh.com/rest_api/v1/',
                           EXTERNAL_TICKET_SYSTEM_API_KEY: 'test-key',
                           EXTERNAL_TICKET_DEPARTMENT_ID: '1') do
          perform_enqueued_jobs { described_class.perform_later(conversation, 'Escalate please') }
        end

        expect(ticket_client).to have_received(:create_ticket).with(
          hash_including(userid: '10', contactid: '1', department: '1',
                         subject: "[Tekomi Chatbot] Acme Ltd - #{contact.reload.name}")
        )
        delivery = conversation.reload.custom_attributes['crm_ticket']
        expect(delivery['ticket_id']).to eq(77)
        expect(delivery['sent_at']).to be_present
      end

      it 'falls back to the plain subject when the contact has no company' do
        contact.update!(company_id: nil)

        with_modified_env(EXTERNAL_TICKET_SYSTEM_URL: 'https://crm.techxanh.com/rest_api/v1/',
                           EXTERNAL_TICKET_SYSTEM_API_KEY: 'test-key',
                           EXTERNAL_TICKET_DEPARTMENT_ID: '1') do
          perform_enqueued_jobs { described_class.perform_later(conversation, 'note') }
        end

        expect(ticket_client).to have_received(:create_ticket).with(
          hash_including(subject: "[Tekomi Chatbot] #{contact.reload.name}", userid: '10', contactid: '1')
        )
      end

      it 'clears any stale failure markers on a successful delivery' do
        conversation.update!(custom_attributes: { 'crm_ticket_error' => 'old', 'keep' => 'me' })

        with_modified_env(EXTERNAL_TICKET_SYSTEM_URL: 'https://crm.techxanh.com/rest_api/v1/',
                           EXTERNAL_TICKET_SYSTEM_API_KEY: 'test-key') do
          perform_enqueued_jobs { described_class.perform_later(conversation, 'note') }
        end

        attrs = conversation.reload.custom_attributes
        expect(attrs['keep']).to eq('me')
        expect(attrs).not_to include('crm_ticket_error')
        expect(attrs['crm_ticket']['sent_at']).to be_present
      end
    end

    context 'when every delivery attempt fails' do
      let!(:account) { create(:account) }
      let(:contact) do
        create(:contact, account: account,
                         additional_attributes: { 'external' => { 'perfex_contact_id' => '1' } })
      end
      let(:conversation) { create(:conversation, account: account, contact: contact) }

      before do
        allow(ticket_client).to receive(:create_ticket).and_raise(
          Crm::Perfex::Api::BaseClient::ApiError.new('crm down', 503, nil)
        )
      end

      it 'retries and finally persists an error marker on the conversation' do
        with_modified_env(EXTERNAL_TICKET_SYSTEM_URL: 'https://crm.techxanh.com/rest_api/v1/',
                           EXTERNAL_TICKET_SYSTEM_API_KEY: 'test-key',
                           EXTERNAL_TICKET_DEPARTMENT_ID: '1') do
          perform_enqueued_jobs { described_class.perform_later(conversation, 'note') }
        end

        attrs = conversation.reload.custom_attributes
        expect(attrs['crm_ticket_error']).to eq('crm down')
        expect(attrs['crm_ticket_failed_at']).to be_present
      end
    end

    context 'when the contact has no matched CRM ids' do
      let!(:account) { create(:account) }
      let(:contact) { create(:contact, account: account) }
      let(:conversation) { create(:conversation, account: account, contact: contact) }

      it 'does not call the CRM' do
        perform_enqueued_jobs { described_class.perform_later(conversation, 'note') }

        expect(ticket_client).not_to have_received(:create_ticket)
      end
    end
  end
end
