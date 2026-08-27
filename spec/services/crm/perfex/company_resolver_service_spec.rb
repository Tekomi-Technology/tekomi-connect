require 'rails_helper'

RSpec.describe Crm::Perfex::CompanyResolverService do
  let(:account) { create(:account) }
  let(:customer_client) { instance_double(Crm::Perfex::Api::CustomerClient) }
  let(:service) { described_class.new(customer_client) }

  describe '#resolve' do
    context 'when the userid is blank' do
      it 'returns nil without contacting the CRM' do
        allow(customer_client).to receive(:show)

        expect(service.resolve(account, '')).to be_nil
        expect(customer_client).not_to have_received(:show)
      end
    end

    context 'when a company for the customer already exists' do
      let!(:company) do
        create(:company, account: account,
                         additional_attributes: { 'external' => { 'perfex_customer_id' => '7' } })
      end

      it 'returns the existing company id without contacting the CRM' do
        allow(customer_client).to receive(:show)

        expect(service.resolve(account, '7')).to eq(company.id)
        expect(customer_client).not_to have_received(:show)
      end
    end

    context 'when the customer has no company yet' do
      it 'creates one from the CRM customer details and memoizes repeated lookups' do
        allow(customer_client).to receive(:show).and_return(
          'success' => true,
          'data' => { 'company' => 'Acme Ltd', 'phonenumber' => '024-3775-8899' }
        )

        expect { service.resolve(account, '8') }.to change(Company, :count).by(1)

        company = Company.last
        expect(company.name).to eq('Acme Ltd')
        expect(company.additional_attributes['phonenumber']).to eq('024-3775-8899')
        expect(company.additional_attributes.dig('external', 'perfex_customer_id')).to eq('8')

        expect(service.resolve(account, '8')).to eq(company.id)
        expect(customer_client).to have_received(:show).once
      end
    end

    context 'when the CRM call fails' do
      it 'returns nil instead of breaking the matching run' do
        allow(customer_client).to receive(:show).and_raise(Crm::Perfex::Api::BaseClient::ApiError.new('boom'))

        expect(service.resolve(account, '9')).to be_nil
      end
    end
  end
end
