require 'rails_helper'

RSpec.describe Crm::Perfex::SyncCustomersJob do
  include ActiveJob::TestHelper

  let(:matcher) { instance_double(Crm::Perfex::CustomerMatcherService) }

  before do
    allow(Crm::Perfex::Api::CustomerClient).to receive(:new).and_return(instance_double(Crm::Perfex::Api::CustomerClient))
    allow(Crm::Perfex::CustomerMatcherService).to receive(:new).and_return(matcher)
    allow(matcher).to receive(:match_all)
  end

  describe '#perform' do
    context 'when there are unmatched contacts' do
      it 'matches all unmatched contacts in a single batch call' do
        create(:contact, phone_number: '+841234567890')
        create(:contact, phone_number: '+841234567891')

        with_modified_env(EXTERNAL_TICKET_SYSTEM_URL: 'https://crm.techxanh.com/rest_api/v1/',
                           EXTERNAL_TICKET_SYSTEM_API_KEY: 'test-key') do
          perform_enqueued_jobs { described_class.perform_later }
        end

        expect(matcher).to have_received(:match_all).once
      end
    end

    context 'when there are no unmatched contacts' do
      it 'does not call the matcher' do
        create(:contact, phone_number: '+841234567890',
                          additional_attributes: { 'external' => { 'perfex_id' => '1' } })

        perform_enqueued_jobs { described_class.perform_later }

        expect(matcher).not_to have_received(:match_all)
      end
    end
  end
end
