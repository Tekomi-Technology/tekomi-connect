require 'rails_helper'

RSpec.describe Crm::Perfex::Api::TicketClient do
  let(:base_url) { 'https://crm.techxanh.com/rest_api/v1/' }
  let(:api_key) { SecureRandom.hex }
  let(:client) { described_class.new(base_url: base_url, api_key: api_key) }

  describe '#create_ticket' do
    it 'posts the ticket payload and returns the parsed response' do
      stub_request(:post, "#{base_url}tickets")
        .with(
          body: { subject: 'Cannot log in', message: 'body', department: 1, userid: '1' }.to_json,
          headers: { 'Authorization' => "Bearer #{api_key}" }
        )
        .to_return(status: 200, body: { success: true, ticketid: 10 }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.create_ticket(subject: 'Cannot log in', message: 'body', department: 1, userid: '1')

      expect(result).to eq('success' => true, 'ticketid' => 10)
    end
  end
end
