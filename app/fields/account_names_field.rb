require 'administrate/field/base'

class AccountNamesField < Administrate::Field::Base
  def to_s
    data.map(&:name).join(', ')
  end
end
