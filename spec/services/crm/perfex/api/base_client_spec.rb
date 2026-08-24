require 'rails_helper'

RSpec.describe Crm::Perfex::Api::BaseClient do
  let(:base_url) { 'https://crm.techxanh.com/rest_api/v1/' }
  let(:api_key) { SecureRandom.hex }
  let(:client) { described_class.new(base_url: base_url, api_key: api_key) }
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}"
    }
  end

  describe '#get' do
    let(:full_url) { "#{base_url}ping" }

    context 'when request is successful' do
      before do
        stub_request(:get, full_url)
          .with(query: { foo: 'bar' }, headers: headers)
          .to_return(status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns parsed response data' do
        expect(client.get('ping', { foo: 'bar' })).to eq('success' => true)
      end
    end

    context 'when request returns error status' do
      before do
        stub_request(:get, full_url)
          .with(query: {}, headers: headers)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ApiError' do
        expect { client.get('ping') }.to raise_error do |error|
          expect(error.class.name).to eq(described_class::ApiError.name)
          expect(error.code).to eq(500)
        end
      end
    end

    context 'when the response body indicates failure' do
      before do
        stub_request(:get, full_url)
          .with(query: {}, headers: headers)
          .to_return(status: 200, body: { success: false, message: 'Invalid token' }.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ApiError with the message' do
        expect { client.get('ping') }.to raise_error do |error|
          expect(error.class.name).to eq(described_class::ApiError.name)
          expect(error.message).to eq('Invalid token')
        end
      end
    end

    context 'when the connection fails at the network level' do
      before do
        stub_request(:get, full_url)
          .with(query: {}, headers: headers)
          .to_raise(Errno::ECONNREFUSED)
      end

      it 'raises ApiError' do
        expect { client.get('ping') }.to raise_error do |error|
          expect(error.class.name).to eq(described_class::ApiError.name)
        end
      end
    end
  end

  describe '#post' do
    let(:full_url) { "#{base_url}tickets" }
    let(:body) { { subject: 'Test' } }

    it 'sends a POST request with a JSON body and returns parsed response' do
      stub_request(:post, full_url)
        .with(body: body.to_json, headers: headers)
        .to_return(status: 200, body: { success: true, ticketid: 5 }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect(client.post('tickets', body)).to eq('success' => true, 'ticketid' => 5)
    end
  end
end
