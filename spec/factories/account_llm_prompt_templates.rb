# frozen_string_literal: true

FactoryBot.define do
  factory :account_llm_prompt_template do
    account
    key { 'reply' }
    body { 'Reply to the customer.' }
  end
end
