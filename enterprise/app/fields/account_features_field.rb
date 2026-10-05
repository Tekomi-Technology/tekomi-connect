require 'administrate/field/base'

class AccountFeaturesField < Administrate::Field::Base
  def to_s
    data
  end

  def selected_features
    resource.selected_feature_flags.map(&:to_s)
  end

  def enabled?(name)
    selected_features.include?("feature_#{name}")
  end

  def hidden_selected_features
    hidden = SuperAdmin::AccountFeaturesHelper.hidden_feature_names(data)
    selected_features.select { |flag| hidden.include?(flag.delete_prefix('feature_')) }
  end
end
