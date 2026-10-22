# Two-way sync between the tickets of one pipeline and an external source, written against
# TicketSources::ExternalTicket only. The external source is the master: whatever it changed wins.
# Echoes are recognised by fingerprints stored on the link, so a change we pushed is not applied back.
class TicketSources::SyncService
  LOCK_TTL = 5.minutes
  RECONCILE_OVERLAP = 10.minutes
  MAX_ATTACHMENT_SIZE = 25.megabytes
  NOTE_ACTION = TicketActivity::NOTE_ACTION

  pattr_initialize :connection

  # --- external source -> tickets -------------------------------------------------------------

  def pull(external_id)
    locked(external_id) { apply(adapter.fetch_ticket(external_id)) }
  end

  def remove(external_id)
    locked(external_id) do
      link = connection.external_links.find_by(external_id: external_id)
      next unless link

      link.ticket.activities.create!(action: 'external_deleted', metadata: { key: link.external_key })
      link.destroy!
    end
  end

  def reconcile
    started_at = Time.current
    failed = false
    adapter.each_ticket_updated_since(connection.last_synced_at && connection.last_synced_at - RECONCILE_OVERLAP) do |external|
      locked(external.id) { apply(external) }
    rescue StandardError => e
      failed = true
      Rails.logger.error("[TicketSources] reconcile #{connection.id} #{external.key}: #{e.class} #{e.message}")
      connection.record_error(e)
    end
    connection.update!(last_synced_at: started_at, last_error: nil) unless failed
  end

  # Mirrors the source's statuses as stages of the pipeline.
  def sync_statuses
    adapter.statuses.each { |status| stage_for(status) }
  end

  # --- tickets -> external source -------------------------------------------------------------

  def push_ticket(ticket)
    link = ticket.external_link
    return unless link

    locked(link.external_id) do
      next if link.local_hash == local_fingerprint(ticket)

      remote = adapter.fetch_ticket(link.external_id)
      next apply(remote) if remote.fingerprint != link.external_hash

      adapter.update_ticket(link.external_id, title: ticket.title, description: ticket.description.to_s)
      store(link, adapter.fetch_ticket(link.external_id))
    end
  end

  def push_new_ticket(ticket)
    locked('create') do
      next if ticket.external_link

      external = adapter.create_ticket(ticket)
      store(ticket.build_external_link(connection: connection, external_id: external.id), external)
    end
  end

  def push_comment(activity)
    link = activity.ticket.external_link
    return unless link

    locked(link.external_id) do
      next if activity.metadata['external_id']

      external_id = adapter.add_comment(link.external_id, "#{activity.actor&.name}: #{activity.content}")
      activity.update!(metadata: activity.metadata.merge('external_provider' => connection.provider, 'external_id' => external_id, 'origin' => 'local'))
    end
  end

  def push_attachment(ticket, blob)
    link = ticket.external_link
    return unless link

    locked(link.external_id) do
      next if blob.metadata['external_id']

      external_id = adapter.add_attachment(link.external_id, blob.filename.to_s, blob.content_type, StringIO.new(blob.download))
      blob.update!(metadata: blob.metadata.merge('external_id' => external_id))
    end
  end

  private

  def adapter
    @adapter ||= connection.adapter
  end

  def apply(external)
    return unless adapter.in_scope?(external)

    link = connection.external_links.find_by(external_id: external.id)
    link = link ? refresh(link, external) : import(external)
    sync_comments(link.ticket, external)
    sync_attachments(link.ticket, external)
    link
  end

  def refresh(link, external)
    return link if link.external_hash == external.fingerprint

    TicketSources::SyncContext.run do
      ticket = link.ticket
      ticket.update!(title: external.title, description: external.description)
      stage = stage_for(external.status)
      ::Tickets::MoveService.new(ticket: ticket, stage: stage).perform if ticket.stage_id != stage.id
    end
    store(link, external)
  end

  def import(external)
    locked('create') do
      TicketSources::SyncContext.run do
        ticket = connection.account.tickets.create!(stage: stage_for(external.status), title: external.title,
                                                    description: external.description, created_by: :webhook)
        store(ticket.build_external_link(connection: connection, external_id: external.id), external)
      end
    end
  end

  def store(link, external)
    link.update!(
      external_key: external.key, external_url: external.url, external_hash: external.fingerprint,
      local_hash: local_fingerprint(link.ticket), external_updated_at: external.updated_at,
      external_data: { 'status' => external.status, 'assignee' => external.assignee }
    )
    link
  end

  def local_fingerprint(ticket)
    Digest::SHA256.hexdigest([ticket.title.to_s.strip, adapter.canonical_text(ticket.description)].to_json)
  end

  def stage_for(status)
    stages = connection.pipeline.stages
    stages.find_by(id: connection.settings.dig('status_map', status[:id])) || create_stage_for(status)
  end

  def create_stage_for(status)
    stages = connection.pipeline.stages
    stage = stages.find_by('LOWER(name) = ?', status[:name].downcase) || stages.create!(
      name: status[:name], stage_type: status[:category] == 'done' ? :won : :open,
      color: PipelineStage::DEFAULT_COLORS[stages.count % PipelineStage::DEFAULT_COLORS.size]
    )
    connection.update!(settings: connection.settings.deep_merge('status_map' => { status[:id] => stage.id }))
    stage
  end

  def sync_comments(ticket, external)
    notes = ticket.activities.where(action: NOTE_ACTION).where("metadata->>'external_provider' = ?", connection.provider)
                  .index_by { |note| note.metadata['external_id'] }
    external.comments.each do |comment|
      note = notes.delete(comment[:id])
      if note.nil?
        create_note(ticket, comment)
      elsif note.metadata['origin'] != 'local' && note.content != comment[:body]
        note.update!(metadata: note.metadata.merge('content' => comment[:body]))
      end
    end
    notes.each_value(&:destroy!)
  end

  def create_note(ticket, comment)
    ticket.activities.create!(
      action: NOTE_ACTION, created_at: comment[:created_at],
      metadata: { content: comment[:body], external_provider: connection.provider, external_id: comment[:id], external_author: comment[:author] }
    )
  end

  def sync_attachments(ticket, external)
    external_ids = external.attachments.pluck(:id)
    synced = ticket.attachments.select { |attachment| attachment.blob.metadata['external_id'].present? }
    synced.each { |attachment| attachment.purge_later if external_ids.exclude?(attachment.blob.metadata['external_id']) }
    known = synced.map { |attachment| attachment.blob.metadata['external_id'] }
    external.attachments.each do |attachment|
      next if known.include?(attachment[:id]) || attachment[:size].to_i > MAX_ATTACHMENT_SIZE

      ticket.attachments.attach(io: StringIO.new(adapter.download_attachment(attachment)), filename: attachment[:filename],
                                content_type: attachment[:mime_type], metadata: { 'external_id' => attachment[:id] })
    end
  end

  # One lock per external issue serialises pulls and pushes of the same ticket; 'create' serialises link creation.
  def locked(key)
    result = nil
    lock_key = "TICKET_SOURCE_SYNC::#{connection.id}::#{key}"
    acquired = Redis::LockManager.new.with_lock(lock_key, LOCK_TTL) { result = yield }
    raise MutexApplicationJob::LockAcquisitionError, "Failed to acquire lock for key: #{lock_key}" unless acquired

    result
  end
end
