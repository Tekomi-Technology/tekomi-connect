class Tekomi::Llm::CareSuggestionSchema < RubyLLM::Schema
  string :next_action, description: 'The single most useful thing the support or sales staff should do next, as one short phrase.', max_length: 120
  array :talking_points, description: 'What to focus on when talking to this customer next time. Short phrases, one idea per item.', max_items: 3 do
    string max_length: 100
  end
  string :opportunity, description: 'Sales or upsell opportunity as one short phrase, or an empty string when there is none.', max_length: 120
  string :contact_timing, description: 'When to contact the customer next, as a few words, for example within 1 to 2 days.', max_length: 40
end
