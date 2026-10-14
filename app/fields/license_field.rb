require 'administrate/field/base'

class LicenseField < Administrate::Field::Base
  # Derived from a has_one, so the list column cannot be ordered in SQL.
  def self.sortable?
    false
  end

  def to_s
    return '-' if data.blank?

    "#{data.plan_key} / #{data.current_state}"
  end

  def state
    data&.current_state
  end
end
