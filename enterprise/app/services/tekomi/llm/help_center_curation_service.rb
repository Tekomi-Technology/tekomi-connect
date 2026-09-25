class Tekomi::Llm::HelpCenterCurationService < Tekomi::BaseTaskService
  RESPONSE_SCHEMA = Tekomi::Llm::HelpCenterCurationSchema
  MAX_LINKS_IN_PROMPT = 50
  IGNORED_URL_PATTERN = /\.(?:pdf|jpe?g|png|gif|webp|svg|ico|bmp|tiff?|avif|heic)(?:\?|#|$)/i

  pattr_initialize [:account!, :links!]

  def perform
    response = make_api_call(feature: 'help_center_curation', messages: messages, schema: RESPONSE_SCHEMA)
    return response if response[:error]

    response.merge(message: extract_payload(response[:message]))
  end

  private

  def extract_payload(message)
    return { categories: [], articles: [] } if message.blank?

    data = message.is_a?(Hash) ? message.deep_symbolize_keys : {}
    articles = Array(data[:articles])
    used_names = articles.map { |a| a[:category_name].to_s }
    categories = Array(data[:categories]).select { |c| used_names.include?(c[:name].to_s) }
    { categories: categories, articles: articles }
  end

  def messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: user_prompt }
    ]
  end

  def system_prompt
    Tekomi::PromptRenderer.render('help_center_curation', locale_name: locale_name)
  end

  def user_prompt
    parts = [
      "Company: #{account.name}",
      ("Description: #{brand_info[:description]}" if brand_info[:description].present?),
      ("Industries: #{industries_text}" if industries_text.present?),
      'Discovered pages (url — title — description):',
      formatted_links
    ].compact
    parts.join("\n")
  end

  def locale_name
    code = account.locale.to_s
    LANGUAGES_CONFIG.values.find { |v| v[:iso_639_1_code] == code }&.dig(:name) || code.presence || 'English (en)'
  end

  def formatted_links
    Array(links).reject { |link| ignored_url?(link) }.first(MAX_LINKS_IN_PROMPT).map do |link|
      data = link.is_a?(Hash) ? link.deep_symbolize_keys : {}
      "- #{data[:url]} — #{data[:title].to_s.strip} — #{data[:description].to_s.strip}"
    end.join("\n")
  end

  def ignored_url?(link)
    url = link.is_a?(Hash) ? link.deep_symbolize_keys[:url].to_s : link.to_s
    url.match?(IGNORED_URL_PATTERN)
  end

  def brand_info
    @brand_info ||= (account.custom_attributes['brand_info'] || {}).deep_symbolize_keys
  end

  def industries_text
    Array(brand_info[:industries]).filter_map { |i| i.is_a?(Hash) ? i[:industry] : i }.join(', ').presence
  end

  def event_name
    'help_center_curation'
  end

  def tekomi_tasks_enabled?
    true
  end

  # Onboarding curation runs on the operator's OpenAI key; it should not
  # debit the customer's tekomi_responses quota.
  def counts_toward_usage?
    false
  end

  def build_follow_up_context?
    false
  end
end
