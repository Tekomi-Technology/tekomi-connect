tenant_branding_profile = TenantBranding::ProfileResolver.resolve(request.host)
account_users = resource.account_users.includes(:account)
account_users = account_users.where(account_id: tenant_branding_profile.account_id) if tenant_branding_profile
display_account_user = tenant_branding_profile ? account_users.first : resource.active_account_user

json.access_token account_users.any? { |account_user| account_user.account.api_and_webhooks_enabled? } ? resource.access_token.token : ''
json.account_id display_account_user&.account_id
json.available_name resource.available_name
json.avatar_url resource.avatar_url
json.confirmed resource.confirmed?
json.display_name resource.display_name
json.message_signature resource.message_signature
json.email resource.email
json.id resource.id
json.inviter_id display_account_user&.inviter_id
json.name resource.name
json.provider resource.provider
json.pubsub_token resource.pubsub_token
json.custom_attributes resource.custom_attributes if resource.custom_attributes.present?
json.role display_account_user&.role
json.ui_settings resource.ui_settings
json.uid resource.uid
json.type resource.type
json.accounts do
  json.array! account_users do |account_user|
    json.id account_user.account_id
    json.name account_user.account.name
    json.status account_user.account.status
    json.onboarding_step account_user.account.onboarding_step
    json.active_at account_user.active_at
    json.role account_user.role
    json.permissions account_user.permissions
    # the actual availability user has configured
    json.availability account_user.availability
    # availability derived from presence
    json.availability_status account_user.availability_status
    json.auto_offline account_user.auto_offline
    json.api_and_webhooks account_user.account.feature_enabled?('api_and_webhooks')
    json.partial! 'api/v1/models/account_user', account_user: account_user if ChatwootApp.enterprise?
  end
end
