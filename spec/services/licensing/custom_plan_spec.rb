require 'rails_helper'

RSpec.describe Licensing::CustomPlan do
  let(:account) { create(:account) }

  def run(attrs)
    described_class.new(account: account, params: ActionController::Parameters.new(attrs).permit!).perform
  end

  it 'creates a custom license with blank limits meaning unlimited' do
    license = run(messages: '1000', call_minutes: '', agents: '5', expires_on: '2026-12-31', channels: { zalo_oa: '2', phone: '0', email: '' })

    expect(license.plan_key).to eq('custom')
    expect(license.quotas).to eq('messages' => 1000, 'agents' => 5, 'inboxes_by_channel' => { 'zalo_oa' => 2, 'phone' => 0 })
    expect(license.expires_at.to_date).to eq(Date.new(2026, 12, 31))
  end

  it 'keeps the existing plan key and replaces limits when editing' do
    Licensing::PlanAssigner.new(account: account, plan_key: 'pro').perform
    license = run(messages: '10', overage_policy: 'allow')

    expect(license.plan_key).to eq('pro')
    expect(license.quotas).to eq('messages' => 10)
    expect(license.overage_policy).to eq('allow')
  end

  it 'rejects negative and non-numeric values' do
    expect { run(messages: '-5') }.to raise_error(described_class::InvalidInput)
    expect { run(messages: 'abc') }.to raise_error(described_class::InvalidInput)
  end
end
