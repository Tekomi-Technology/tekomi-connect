require 'rails_helper'

RSpec.describe Tekomi::Tools::FirecrawlService do
  let(:account) { create(:account) }
  let(:api_key) { 'test-api-key' }
  let(:url) { 'https://example.com' }
  let(:webhook_url) { 'https://webhook.example.com/callback' }
  let(:crawl_limit) { 15 }

  before do
    allow(Firecrawl::Configuration).to receive(:api_key).with(account: account).and_return(api_key)
  end

  describe '#initialize' do
    context 'when the account has an API key' do
      it 'initializes successfully' do
        expect { described_class.new(account) }.not_to raise_error
      end
    end

    context 'when the account has no API key' do
      before do
        allow(Firecrawl::Configuration).to receive(:api_key).with(account: account).and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.new(account) }.to raise_error('Missing API key')
      end
    end

    context 'when the account API key is empty' do
      before do
        allow(Firecrawl::Configuration).to receive(:api_key).with(account: account).and_return('')
      end

      it 'raises an error' do
        expect { described_class.new(account) }.to raise_error('Missing API key')
      end
    end
  end

  describe '#perform' do
    let(:service) { described_class.new(account) }
    let(:expected_payload) do
      {
        url: url,
        maxDiscoveryDepth: 50,
        sitemap: 'include',
        limit: crawl_limit,
        webhook: { url: webhook_url },
        scrapeOptions: {
          onlyMainContent: true,
          formats: ['markdown'],
          excludeTags: Tekomi::Tools::FirecrawlService::FIRECRAWL_EXCLUDE_TAGS,
          maxAge: 0
        }
      }.to_json
    end

    let(:expected_headers) do
      {
        'Authorization' => "Bearer #{api_key}",
        'Content-Type' => 'application/json'
      }
    end

    context 'when the API call is successful' do
      before do
        stub_request(:post, 'https://api.firecrawl.dev/v2/crawl')
          .with(
            body: expected_payload,
            headers: expected_headers
          )
          .to_return(status: 200, body: '{"status": "success"}')
      end

      it 'makes a POST request with correct parameters' do
        service.perform(url, webhook_url, crawl_limit)

        expect(WebMock).to have_requested(:post, 'https://api.firecrawl.dev/v2/crawl')
          .with(
            body: expected_payload,
            headers: expected_headers
          )
      end

      it 'uses default crawl limit when not specified' do
        default_payload = expected_payload.gsub(crawl_limit.to_s, '10')

        stub_request(:post, 'https://api.firecrawl.dev/v2/crawl')
          .with(
            body: default_payload,
            headers: expected_headers
          )
          .to_return(status: 200, body: '{"status": "success"}')

        service.perform(url, webhook_url)

        expect(WebMock).to have_requested(:post, 'https://api.firecrawl.dev/v2/crawl')
          .with(
            body: default_payload,
            headers: expected_headers
          )
      end
    end

    context 'when the API call fails' do
      before do
        stub_request(:post, 'https://api.firecrawl.dev/v2/crawl')
          .to_raise(StandardError.new('Connection failed'))
      end

      it 'raises an error with the failure message' do
        expect { service.perform(url, webhook_url, crawl_limit) }
          .to raise_error('Failed to crawl URL: Connection failed')
      end
    end

    context 'when the API returns an error response' do
      before do
        stub_request(:post, 'https://api.firecrawl.dev/v2/crawl')
          .to_return(status: 422, body: '{"error": "Invalid URL"}')
      end

      it 'makes the request but does not raise an error' do
        expect { service.perform(url, webhook_url, crawl_limit) }.not_to raise_error

        expect(WebMock).to have_requested(:post, 'https://api.firecrawl.dev/v2/crawl')
          .with(
            body: expected_payload,
            headers: expected_headers
          )
      end
    end
  end
end
