require 'rails_helper'

RSpec.describe Crm::Perfex::ContactMatcherService do
  let(:contact_client) { instance_double(Crm::Perfex::Api::ContactClient) }
  let(:customer_client) { instance_double(Crm::Perfex::Api::CustomerClient, show: { 'success' => true, 'data' => {} }) }
  let(:perfex_contacts) { [] }
  let(:service) { described_class.new(contact_client: contact_client, customer_client: customer_client) }
  let(:company) do
    create(:company, account: account,
                     additional_attributes: { 'external' => { 'perfex_customer_id' => '10' } })
  end

  before do
    allow(contact_client).to receive(:fetch_all_contacts).and_return(perfex_contacts)
    allow(customer_client).to receive(:show)
  end

  describe '#match_one' do
    context 'when the contact matches by email' do
      let!(:account) { create(:account) }
      let(:contact) do
        create(:contact, account: account, name: 'Local Name', phone_number: '+84911111222',
                         email: 'jane@x.com')
      end
      let(:perfex_contacts) do
        [{ 'id' => '1', 'userid' => '10', 'firstname' => 'CRM', 'lastname' => 'Doe',
           'email' => 'JANE@x.com', 'phonenumber' => '0901234567' }]
      end

      it 'links the CRM ids and company without overwriting local fields' do
        expect(service.match_one(contact)).to eq(contact)

        attrs = contact.reload.additional_attributes
        expect(attrs.dig('external', 'perfex_contact_id')).to eq('1')
        expect(attrs.dig('external', 'perfex_customer_id')).to eq('10')
        expect(attrs.dig('crm', 'name')).to eq('CRM Doe')
        expect(attrs['crm']).not_to have_key('match_failed_at')
        expect(contact.company_id).to eq(company.id)
        expect(contact.name).to eq('Local Name')
        expect(contact.phone_number).to eq('+84911111222')
        expect(contact.phone_number_was).to eq('+84911111222')
      end
    end

    context 'when the contact matches by phone only' do
      let!(:account) { create(:account) }
      let(:contact) { create(:contact, account: account, phone_number: '+84 901 234 567') }
      let(:perfex_contacts) do
        [{ 'id' => '2', 'userid' => '11', 'firstname' => 'Phoned', 'lastname' => 'In',
           'email' => '', 'phonenumber' => '0901234567' }]
      end

      it 'matches after normalizing both numbers' do
        service.match_one(contact)

        expect(contact.reload.additional_attributes.dig('external', 'perfex_contact_id')).to eq('2')
      end
    end

    context 'when no CRM contact matches' do
      let!(:account) { create(:account) }
      let(:contact) { create(:contact, account: account, phone_number: '+84123456789') }

      it 'records the failure timestamp' do
        service.match_one(contact)

        attrs = contact.reload.additional_attributes
        expect(attrs['external'] || {}).not_to have_key('perfex_contact_id')
        expect(attrs.dig('crm', 'match_failed_at')).to be_present
      end
    end

    context 'when the account has an existing customer with a different company id format' do
      # userid arrives as integer in some Perfex payloads; resolution must still link
      let!(:account) { create(:account) }
      let(:contact) { create(:contact, account: account, email: 'int@example.com') }
      let(:perfex_contacts) do
        [{ 'id' => '3', 'userid' => 12, 'firstname' => 'Int', 'lastname' => 'User',
           'email' => 'int@example.com', 'phonenumber' => '' }]
      end

      it 'resolves and links the company' do
        existing = create(:company, account: account,
                                    additional_attributes: { 'external' => { 'perfex_customer_id' => '12' } })

        service.match_one(contact)

        expect(contact.reload.company_id).to eq(existing.id)
      end
    end

    context 'when repeated calls run against the cache' do
      let!(:account) { create(:account) }
      let(:contact) { create(:contact, account: account, email: 'cache@example.com') }
      let(:perfex_contacts) do
        [{ 'id' => '4', 'userid' => '13', 'firstname' => 'Cache', 'lastname' => 'Hit',
           'email' => 'cache@example.com', 'phonenumber' => '' }]
      end

      it 'crawls the CRM only once across matcher instances' do
        described_class.new(contact_client: contact_client, customer_client: customer_client).match_one(contact)
        described_class.new(contact_client: contact_client, customer_client: customer_client).match_one(contact.reload)

        expect(contact_client).to have_received(:fetch_all_contacts).once
      end
    end
  end

  describe '#match_all' do
    let!(:account) { create(:account) }
    let(:matched) { create(:contact, account: account, email: 'one@example.com') }
    let(:unmatched) { create(:contact, account: account, email: 'none@example.com') }
    let(:perfex_contacts) do
      [{ 'id' => '5', 'userid' => '14', 'firstname' => 'One', 'lastname' => '',
         'email' => 'one@example.com', 'phonenumber' => '' }]
    end

    it 'returns the number of contacts matched' do
      expect(service.match_all(Contact.all)).to eq(1)
      expect(matched.reload.additional_attributes.dig('external', 'perfex_contact_id')).to eq('5')
      expect(unmatched.reload.additional_attributes.dig('crm', 'match_failed_at')).to be_present
    end
  end
end
