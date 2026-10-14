require 'rails_helper'

RSpec.describe Licensing::PlanAssigner do
  let(:account) { create(:account) }

  it 'snapshots the trial preset onto the account' do
    license = described_class.new(account: account, plan_key: 'trial').perform

    expect(license).to be_trial
    expect(license.expires_at).to be_within(1.minute).of(14.days.from_now)
    expect(license.quota('messages')).to eq(500)
    expect(license.enforce).to be(false)
    expect(account.reload.feature_enabled?('channel_zalo_oa')).to be(true)
    expect(account.feature_enabled?('crm')).to be(false)
  end

  it 'replaces managed features when changing plan but keeps unrelated flags' do
    account.enable_features('ip_lookup')
    account.save!
    described_class.new(account: account, plan_key: 'pro').perform
    described_class.new(account: account, plan_key: 'trial').perform

    account.reload
    expect(account.feature_enabled?('sla')).to be(false)
    expect(account.feature_enabled?('ip_lookup')).to be(true)
  end

  it 'honours a custom duration and enforce flag' do
    license = described_class.new(account: account, plan_key: 'starter', enforce: true, duration_days: 90).perform

    expect(license.enforce).to be(true)
    expect(license.expires_at).to be_within(1.minute).of(90.days.from_now)
  end

  it 'raises for unknown plans' do
    expect { described_class.new(account: account, plan_key: 'nope').perform }.to raise_error(described_class::UnknownPlan)
  end

  it 'lets the license cap agents and inboxes on self-hosted installs' do
    described_class.new(account: account, plan_key: 'trial').perform
    expect(account.reload.usage_limits).to include(agents: 3, inboxes: 3)
  end
end
