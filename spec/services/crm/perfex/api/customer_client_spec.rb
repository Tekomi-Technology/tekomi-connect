require 'rails_helper'

RSpec.describe Crm::Perfex::Api::CustomerClient do
  let(:base_url) { 'https://crm.techxanh.com/rest_api/v1/' }
  let(:api_key) { SecureRandom.hex }
  let(:client) { described_class.new(base_url: base_url, api_key: api_key) }
  let(:headers) { { 'Authorization' => "Bearer #{api_key}" } }

  describe '#fetch_all_customers' do
    it 'returns all customers when everything fits on one page' do
      stub_request(:get, "#{base_url}customers")
        .with(query: { page: 1, per_page: 20 }, headers: headers)
        .to_return(
          status: 200,
          body: {
            success: true,
            data: [{ 'userid' => '1', 'company' => 'Acme', 'phonenumber' => '024-3775-8899' }],
            meta: { page: 1, per_page: 20, total: 1 }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.fetch_all_customers

      expect(result).to eq([{ 'userid' => '1', 'company' => 'Acme', 'phonenumber' => '024-3775-8899' }])
    end

    it 'loops through multiple pages until all customers are fetched' do
      stub_request(:get, "#{base_url}customers")
        .with(query: { page: 1, per_page: 20 })
        .to_return(
          status: 200,
          body: { success: true, data: [{ 'userid' => '1' }], meta: { page: 1, per_page: 20, total: 2 } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, "#{base_url}customers")
        .with(query: { page: 2, per_page: 20 })
        .to_return(
          status: 200,
          body: { success: true, data: [{ 'userid' => '2' }], meta: { page: 2, per_page: 20, total: 2 } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.fetch_all_customers

      expect(result).to eq([{ 'userid' => '1' }, { 'userid' => '2' }])
    end
  end
end
