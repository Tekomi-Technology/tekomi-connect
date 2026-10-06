# frozen_string_literal: true

FactoryBot.define do
  factory :ai_alert do
    association :account
    category { 'quota' }
    feature { 'reply' }
    provider { 'openrouter' }
    sequence(:title) { |n| "AI alert #{n}" }
    message { 'The provider rejected the request.' }
    sequence(:fingerprint) { |n| "fingerprint-#{n}" }
    last_seen_at { Time.current }
  end
end
