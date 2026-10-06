json.id resource.id
json.name resource.name
json.description resource.description
json.allow_auto_assign resource.allow_auto_assign
json.icon resource.icon
json.icon_color resource.icon_color
json.account_id resource.account_id
json.supervisor_id resource.supervisor_id
json.supervisor do
  if resource.supervisor
    json.partial! 'api/v1/models/agent', formats: [:json], resource: resource.supervisor
  else
    json.nil!
  end
end
json.is_member Current.user.teams.include?(resource)
