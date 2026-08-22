require 'rails_helper'

RSpec.describe Crm::Perfex::TicketDeliveryJob do
  include ActiveJob::TestHelper

  let(:ticket_client) { instance_double(Crm::Perfex::Api::TicketClient) }

  before do
    allow(Crm::Perfex::Api::TicketClient).to receive(:new).and_return(ticket_client)
    allow(ticket_client).to receive(:create_ticket).and_return('success' => true)
  end

  describe '#perform' do
    context 'when the contact has a matched CRM userid' do
      let(:contact) { create(:contact, additional_attributes: { 'external' => { 'perfex_id' => '1' } }) }
      let(:conversation) { create(:conversation, contact: contact) }

      it 'creates a ticket with the matched CRM userid and the note' do
        with_modified_env(EXTERNAL_TICKET_SYSTEM_URL: 'https://crm.techxanh.com/rest_api/v1/',
                           EXTERNAL_TICKET_SYSTEM_API_KEY: 'test-key',
                           EXTERNAL_TICKET_DEPARTMENT_ID: '1') do
          perform_enqueued_jobs { described_class.perform_later(conversation, 'Escalate please') }
        end

        expect(ticket_client).to have_received(:create_ticket).with(
          hash_including(userid: '1', message: a_string_including('Escalate please'))
        )
      end
    end

    context 'when the contact has no matched CRM userid' do
      let(:contact) { create(:contact) }
      let(:conversation) { create(:conversation, contact: contact) }

      it 'does not call the CRM' do
        perform_enqueued_jobs { described_class.perform_later(conversation, 'note') }

        expect(ticket_client).not_to have_received(:create_ticket)
      end
    end
  end
end
