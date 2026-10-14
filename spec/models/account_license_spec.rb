require 'rails_helper'

RSpec.describe AccountLicense do
  let(:account) { create(:account) }

  describe '#current_state' do
    it 'is trial before expiry for trial licenses' do
      license = build(:account_license, account: account, trial: true, expires_at: 3.days.from_now)
      expect(license.current_state).to eq('trial')
    end

    it 'is active before expiry for paid licenses and when there is no expiry' do
      expect(build(:account_license, account: account).current_state).to eq('active')
      expect(build(:account_license, account: account, expires_at: nil).current_state).to eq('active')
    end

    it 'moves through grace to restricted' do
      license = build(:account_license, account: account, expires_at: 1.day.ago, grace_days: 3)
      expect(license.current_state).to eq('grace')
      expect(license.current_state(5.days.from_now)).to eq('restricted')
    end

    it 'is suspended regardless of dates' do
      expect(build(:account_license, account: account, suspended: true).current_state).to eq('suspended')
    end
  end

  describe '#period_start' do
    it 'is fixed to the start date for trials' do
      license = build(:account_license, account: account, trial: true, starts_at: Time.zone.parse('2026-01-15'))
      expect(license.period_start(Time.zone.parse('2026-03-20'))).to eq(Date.new(2026, 1, 15))
    end

    it 'rolls monthly from the anchor day for paid licenses' do
      license = build(:account_license, account: account, starts_at: Time.zone.parse('2026-01-15'))
      expect(license.period_start(Time.zone.parse('2026-03-20'))).to eq(Date.new(2026, 3, 15))
      expect(license.period_start(Time.zone.parse('2026-03-10'))).to eq(Date.new(2026, 2, 15))
    end
  end

  it 'rejects negative quotas' do
    license = build(:account_license, account: account, quotas: { 'messages' => -1 })
    expect(license).not_to be_valid
  end
end
