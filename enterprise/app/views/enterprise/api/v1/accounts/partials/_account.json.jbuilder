json.subscribed_features @account.subscribed_features
license = @account.account_license
if license
  json.license do
    json.state license.current_state
    json.plan_key license.plan_key
    json.trial license.trial?
    json.expires_at license.expires_at
    json.days_left license.days_left
    json.enforce license.enforce?
  end
end
