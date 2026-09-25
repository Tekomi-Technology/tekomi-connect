class ZaloOa::BackfillJob < MutexApplicationJob
  queue_as :low
  retry_on LockAcquisitionError, wait: 10.seconds, attempts: 6

  MAX_CONVERSATIONS = 50
  MAX_MESSAGES_PER_CONVERSATION = 100
  PAGE_SIZE = 10

  def perform(channel_id)
    channel = Channel::ZaloOa.find_by(id: channel_id)
    return if channel.blank? || channel.inbox.blank?

    with_lock("zalo_oa:backfill:#{channel.id}", 5.minutes) { backfill(channel) }
  rescue ZaloOa::Client::Error => e
    Rails.logger.error("Zalo OA history backfill failed for channel #{channel_id}: #{e.message}")
    raise
  end

  private

  def backfill(channel)
    access_token = channel.valid_access_token
    since_ms = channel.backfill_watermark_ms.to_i
    conversations = collect_conversations(channel, access_token)
    max_time_ms = since_ms

    conversations.first(MAX_CONVERSATIONS).each do |conversation|
      next if conversation[:last_time_ms] <= since_ms

      messages = fetch_messages(access_token, conversation[:user_id], since_ms)
      messages.each do |raw|
        params = ZaloOa::BackfillMessage.new(channel: channel, user_id: conversation[:user_id], raw: raw).to_params
        next if params.blank?

        timestamp = params[:timestamp].to_i
        next if timestamp <= since_ms

        ZaloOa::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
        max_time_ms = timestamp if timestamp > max_time_ms
      end
    end

    channel.update!(backfill_watermark_ms: max_time_ms)
  end

  def collect_conversations(channel, access_token)
    rows = []
    offset = 0
    while rows.size < MAX_CONVERSATIONS
      page = ZaloOa::Client.list_recent_chats(
        access_token: access_token, oa_id: channel.oa_id, offset: offset, count: PAGE_SIZE
      )
      break if page.empty?

      rows.concat(page.map { |row| { user_id: row[:user_id].to_s, last_time_ms: row[:time].to_i } })
      offset += page.size
      break if page.size < PAGE_SIZE
    end
    rows
  end

  def fetch_messages(access_token, user_id, since_ms)
    rows = []
    offset = 0
    stop = false
    while !stop && rows.size < MAX_MESSAGES_PER_CONVERSATION
      page = ZaloOa::Client.conversation_messages(
        access_token: access_token, user_id: user_id, offset: offset, count: PAGE_SIZE
      )
      break if page.empty?

      page.each do |row|
        timestamp = (row[:time].presence || row[:timestamp]).to_i
        if timestamp <= since_ms
          stop = true
          break
        end

        rows << row
        break if rows.size >= MAX_MESSAGES_PER_CONVERSATION
      end
      break if stop || page.size < PAGE_SIZE || rows.size >= MAX_MESSAGES_PER_CONVERSATION

      offset += page.size
    end
    rows
  end
end
