class Tekomi::Llm::DealSummarySchema < RubyLLM::Schema
  SUMMARY_DESCRIPTION = 'A short paragraph a salesperson can read in a few seconds: what the customer wants, ' \
                        'where the deal stands, and what was agreed so far.'
  HIGHLIGHTS_DESCRIPTION = 'The few facts that matter most, one short line each: agreed price, requested features, ' \
                           'objections, deadlines or commitments made.'

  string :summary, description: SUMMARY_DESCRIPTION, max_length: 800
  array :highlights, description: HIGHLIGHTS_DESCRIPTION, max_items: 5, of: :string
end
