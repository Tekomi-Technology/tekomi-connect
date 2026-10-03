class Tekomi::Llm::ArticleWriterService < Tekomi::BaseTaskService
  RESPONSE_SCHEMA = Tekomi::Llm::ArticleWriterSchema
  SOURCE_MAX_LENGTH = 60_000

  # source_pages: Array<{ url: String, markdown: String }>, 1-3 entries.
  pattr_initialize [:account!, :source_pages!, { hint_title: nil }]

  def perform
    response = make_api_call(feature: 'help_center_article_generation', messages: messages, schema: RESPONSE_SCHEMA)
    return response if response[:error]

    response.merge(message: extract_payload(response[:message]))
  end

  private

  def extract_payload(message)
    return {} if message.blank?

    data = message.is_a?(Hash) ? message.deep_symbolize_keys : {}
    {
      title: data[:title].to_s.strip,
      description: data[:description].to_s.strip,
      content: data[:content].to_s.strip
    }
  end

  def messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: user_prompt }
    ]
  end

  def system_prompt
    Tekomi::PromptRenderer.render('article_writer', locale_name: locale_name)
  end

  def user_prompt
    pages = Array(source_pages).reject { |p| p[:markdown].to_s.blank? }
    per_source_cap = pages.size.positive? ? SOURCE_MAX_LENGTH / pages.size : SOURCE_MAX_LENGTH

    sections = pages.each_with_index.map do |page, idx|
      body = page[:markdown].to_s.truncate(per_source_cap, omission: "\n\n[source truncated for length]")
      "=== Source #{idx + 1} of #{pages.size} (#{page[:url]}) ===\n#{body}"
    end

    parts = [
      ("Suggested title (you may rewrite): #{hint_title}" if hint_title.present?),
      'Source pages (Markdown):',
      sections.join("\n\n")
    ].compact
    parts.join("\n\n")
  end

  def locale_name
    code = account.locale.to_s
    LANGUAGES_CONFIG.values.find { |v| v[:iso_639_1_code] == code }&.dig(:name) || code.presence || 'English (en)'
  end

  def event_name
    'article_writer'
  end

  def tekomi_tasks_enabled?
    true
  end

  # Rewrite runs on the operator's OpenAI key during onboarding; should not
  # debit the customer's tekomi_responses quota.
  def counts_toward_usage?
    false
  end

  def build_follow_up_context?
    false
  end
end
