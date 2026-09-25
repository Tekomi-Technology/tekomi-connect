json.payload do
  json.analyzed_count @report[:analyzed_count]
  json.average_score @report[:average_score]
  json.criteria @report[:criteria]
  json.served_by @report[:served_by]
  json.agents @report[:agents]
  json.low_scores @report[:low_scores] do |analysis|
    json.partial! 'api/v1/accounts/conversation_analyses/list_item', formats: [:json], analysis: analysis
  end
end
