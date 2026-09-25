class Tekomi::Llm::CareSuggestionSchema < RubyLLM::Schema
  string :next_action, description: 'The single most useful thing the support or sales staff should do next.', max_length: 300
  string :talking_points, description: 'What to focus on when talking to this customer next time.', max_length: 400
  string :opportunity, description: 'Sales or upsell opportunity, or an empty string when there is none.', max_length: 300
  string :contact_timing, description: 'When to contact the customer next, for example within 1 to 2 days.', max_length: 100
end
