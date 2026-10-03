class ConversationAnalyses::JobState
  PROCESSING_TTL = 10.minutes
  FAILED_TTL = 1.hour

  def initialize(conversation, kind)
    @key = "conversation_analysis:#{kind}:#{conversation.id}"
  end

  def start
    Redis::Alfred.delete(@key) if to_h&.dig('status') == 'failed'
    Redis::Alfred.set(@key, { status: 'processing' }.to_json, nx: true, ex: PROCESSING_TTL)
  end

  def fail!(error = nil)
    Redis::Alfred.set(@key, { status: 'failed', error: error }.to_json, ex: FAILED_TTL)
  end

  def finish!
    Redis::Alfred.delete(@key)
  end

  def to_h
    raw = Redis::Alfred.get(@key)
    JSON.parse(raw) if raw.present?
  end
end
