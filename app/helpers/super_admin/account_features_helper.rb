module SuperAdmin::AccountFeaturesHelper
  def self.account_features
    YAML.safe_load(Rails.root.join('config/features.yml').read).freeze
  end

  # Returns a hash mapping feature names to their display names
  def self.feature_display_names
    account_features.each_with_object({}) do |feature, hash|
      hash[feature['name']] = I18n.t("super_admin.account_features.#{feature['name']}", default: feature['display_name'])
    end
  end

  def self.filter_internal_features(features)
    return features if ChatwootApp.chatwoot_cloud?

    internal_features = account_features.select { |f| f['chatwoot_internal'] }.pluck('name')
    features.except(*internal_features)
  end

  def self.filter_deprecated_features(features)
    deprecated_features = account_features.select { |f| f['deprecated'] }.pluck('name')
    features.except(*deprecated_features)
  end

  def self.filtered_features(features)
    filtered = filter_internal_features(features)
    filtered = filter_deprecated_features(filtered)
    display_names = feature_display_names
    filtered.keys.map { |name| [name, display_names[name] || name] }.sort_by(&:last)
  end

  def self.hidden_feature_names(features)
    features.keys - filtered_features(features).map(&:first)
  end
end
