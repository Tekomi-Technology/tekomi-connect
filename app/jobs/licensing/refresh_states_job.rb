# Hourly: persists derived license states and flags transitions in the log.
# Enforcement itself is clock-based (see AccountLicense#current_state), so a late run is harmless.
class Licensing::RefreshStatesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    AccountLicense.find_each do |license|
      new_state = license.current_state
      next if new_state == license.state

      Rails.logger.info("[licensing] account=#{license.account_id} state #{license.state} -> #{new_state}")
      license.update_columns(state: new_state, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
