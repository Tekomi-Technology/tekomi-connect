class Tekomi::Llm::DealNextStepSchema < RubyLLM::Schema
  NEXT_STEP_DESCRIPTION = 'The single most useful thing the salesperson should do next, written as one short instruction ' \
                          'they can act on today.'
  REASON_DESCRIPTION = 'One sentence explaining what in the conversations or history leads to this next step.'
  STAGE_DESCRIPTION = 'The id of the stage this deal should move to, taken from the stage list given to you. ' \
                      'Use 0 when the deal should stay where it is.'

  string :next_step, description: NEXT_STEP_DESCRIPTION, max_length: 300
  string :reason, description: REASON_DESCRIPTION, max_length: 300
  integer :suggested_stage_id, description: STAGE_DESCRIPTION
end
