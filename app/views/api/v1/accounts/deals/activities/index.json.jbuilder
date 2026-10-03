json.payload do
  json.array! @activities do |activity|
    json.id activity.id
    json.action activity.action
    json.metadata activity.metadata
    json.actor activity.actor&.push_event_data
    json.created_at activity.created_at.to_i
  end
end
