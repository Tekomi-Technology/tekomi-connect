if @analysis
  json.payload do
    json.partial! 'api/v1/models/conversation_analysis', formats: [:json], analysis: @analysis
  end
else
  json.payload nil
end
