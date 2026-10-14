# Admin operations on an existing license (extend / suspend / resume / enforcement toggle).
class Licensing::Lifecycle
  def initialize(license, actor: nil)
    @license = license
    @actor = actor
  end

  def extend_days!(days)
    base = [@license.expires_at, Time.current].compact.max
    @license.update!(expires_at: base + days.to_i.days, notified: {})
    log('extend', days: days)
  end

  def suspend!
    @license.update!(suspended: true)
    log('suspend')
  end

  def resume!
    @license.update!(suspended: false)
    log('resume')
  end

  def enforce!(value)
    @license.update!(enforce: value)
    log('enforce', enforce: value)
  end

  private

  def log(action, extra = {})
    Rails.logger.info("[licensing] account=#{@license.account_id} action=#{action} actor=#{@actor&.id} #{extra}")
  end
end
