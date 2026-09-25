json.id analysis.id
json.conversation_id analysis.conversation.display_id
json.served_by analysis.served_by
json.quality_score analysis.quality_score
json.quality analysis.quality
json.customer analysis.customer
json.insight analysis.insight
json.conversation_state analysis.conversation_state
json.care analysis.care
json.analyzed_by do
  json.id analysis.analyzed_by&.id
  json.name analysis.analyzed_by&.available_name
end
json.updated_at analysis.updated_at.to_i
