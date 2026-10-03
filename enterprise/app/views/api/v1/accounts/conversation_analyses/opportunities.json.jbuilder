json.meta do
  json.count @analyses.total_count
  json.current_page @analyses.current_page
end
json.payload @analyses do |analysis|
  json.partial! 'api/v1/accounts/conversation_analyses/list_item', formats: [:json], analysis: analysis
end
