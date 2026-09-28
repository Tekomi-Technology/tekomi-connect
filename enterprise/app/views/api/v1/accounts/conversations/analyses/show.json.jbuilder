if @analysis
  json.payload do
    json.partial! 'api/v1/models/conversation_analysis', formats: [:json], analysis: @analysis
  end
else
  json.payload nil
end
json.jobs do
  json.analysis ConversationAnalyses::JobState.new(@conversation, :analysis).to_h
  json.care ConversationAnalyses::JobState.new(@conversation, :care).to_h
end
