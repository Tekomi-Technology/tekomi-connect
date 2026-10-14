FactoryBot.define do
  factory :account_license do
    account
    plan_key { 'custom' }
    starts_at { Time.current }
    expires_at { 30.days.from_now }
    enforce { true }
    quotas { {} }
  end
end
