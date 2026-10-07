module Firecrawl::Configuration
  SERVICE_TYPE = 'firecrawl'.freeze
  EXCLUDE_TAGS = %w[iframe .sidebar .cookie-banner [role=navigation] [role=banner] [role=contentinfo]].freeze
  DEFAULT_SCRAPE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000

  module_function

  def configured?(account:)
    api_key(account: account).present?
  end

  def client(account:)
    key = api_key(account: account)
    raise ::Firecrawl::FirecrawlError, 'FireCrawl has no API key configured for this account' if key.blank?

    ::Firecrawl::Client.new(api_key: key)
  end

  def api_key(account:)
    account&.account_llm_providers&.find_by(provider_type: SERVICE_TYPE)&.api_key
  end

  def default_scrape_options(max_age: DEFAULT_SCRAPE_MAX_AGE_MS)
    ::Firecrawl::Models::ScrapeOptions.new(
      formats: ['markdown'],
      only_main_content: true,
      exclude_tags: EXCLUDE_TAGS,
      max_age: max_age
    )
  end
end
