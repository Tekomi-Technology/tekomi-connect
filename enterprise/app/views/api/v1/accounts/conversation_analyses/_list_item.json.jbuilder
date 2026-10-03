json.id analysis.id
json.conversation_id analysis.conversation.display_id
json.served_by analysis.served_by
json.quality_score analysis.quality_score
json.customer analysis.customer
json.insight analysis.insight
json.care analysis.care
json.contact do
  json.id analysis.contact.id
  json.name analysis.contact.name
end
json.assignee do
  json.id analysis.assignee&.id
  json.name analysis.assignee&.available_name
end
json.updated_at analysis.updated_at.to_i
