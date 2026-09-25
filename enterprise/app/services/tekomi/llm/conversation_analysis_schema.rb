class Tekomi::Llm::ConversationAnalysisSchema < RubyLLM::Schema
  SERVED_BY_DESCRIPTION = 'Who replied to the customer in this conversation: bot, agent (a human support agent), both, or none.'.freeze
  SCORE_DESCRIPTION = 'Score from 1 (very poor) to 5 (excellent) following the rubric. ' \
                      'Use 0 only when the conversation gives nothing to judge for this criterion.'.freeze
  REASON_DESCRIPTION = 'One or two sentences explaining the score.'.freeze
  EVIDENCE_DESCRIPTION = 'Up to two short quotes copied word for word from the conversation that support the score.'.freeze
  UNKNOWN = 'Empty string when the customer did not mention it.'.freeze
  NONE = 'Empty string when there is none.'.freeze

  string :served_by, description: SERVED_BY_DESCRIPTION, enum: ConversationAnalysis::SERVED_BY

  object :quality do
    ConversationAnalysis::CRITERIA.each do |criterion|
      object criterion.to_sym do
        integer :score, description: SCORE_DESCRIPTION, minimum: 0, maximum: 5
        string :reason, description: REASON_DESCRIPTION, max_length: 400
        array :evidence, description: EVIDENCE_DESCRIPTION, max_items: 2, of: :string
      end
    end
  end

  object :customer do
    string :needs, description: "What the customer said they want to achieve or buy. #{UNKNOWN}", max_length: 300
    string :products_of_interest, description: "Products or services of this business the customer asked about. #{UNKNOWN}", max_length: 200
    string :current_solution, description: "Product, service or provider the customer said they use today. #{UNKNOWN}", max_length: 200
    string :budget, description: "Budget the customer stated, with the amount and period as said. #{UNKNOWN}", max_length: 100
    string :timeline, description: "When the customer said they need it. #{UNKNOWN}", max_length: 100
  end

  object :insight do
    string :summary, description: 'One sentence on who the customer is, what they really need and what holds them back.', max_length: 400
    string :interest_level, description: 'How ready the customer is to buy: high, medium, low, or unknown.',
                            enum: ConversationAnalysis::INTEREST_LEVELS
    string :sentiment, description: 'How the customer feels at the end of the conversation.', enum: ConversationAnalysis::SENTIMENTS
    string :pain_points, description: "The underlying problems or frustrations behind the request. #{NONE}", max_length: 300
    string :barriers, description: "What stops the customer from moving forward, such as price, timing or trust. #{NONE}", max_length: 300
    string :motivations, description: "What the customer values most, such as saving cost or going live fast. #{NONE}", max_length: 300
  end

  object :conversation_state do
    string :already_done, description: "What the bot or agent already did or promised, such as a quote sent or a callback promised. #{NONE}",
                          max_length: 300
    string :open_questions, description: "What the customer asked that has not been answered yet. #{NONE}", max_length: 300
  end
end
