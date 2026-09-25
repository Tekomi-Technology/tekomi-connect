json.payload do
  json.array! @analyses do |analysis|
    json.partial! 'api/v1/models/conversation_analysis', formats: [:json], analysis: analysis
  end
end
