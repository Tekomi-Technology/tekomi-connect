class TicketSources::Jira::Adapter < TicketSources::BaseAdapter
  ISSUE_FIELDS = %w[summary description status assignee updated comment attachment].freeze
  COMMENT_PAGE_SIZE = 100
  SEARCH_PAGE_SIZE = 50
  WEBHOOK_CHANGE_EVENTS = %w[jira:issue_created jira:issue_updated comment_created comment_updated comment_deleted].freeze

  def self.credential_fields
    [
      { key: 'site', label: 'Jira site (your-team.atlassian.net)', secret: false },
      { key: 'email', label: 'Atlassian account email', secret: false },
      { key: 'api_token', label: 'API token', secret: true }
    ]
  end

  def self.setting_fields
    [
      { key: 'project_key', label: 'Project key', required: true },
      { key: 'issue_type_id', label: 'Issue type id used for tickets created here' },
      { key: 'push_new_tickets', label: 'Create a Jira issue for every new ticket in this pipeline', type: 'boolean' }
    ]
  end

  def verify_webhook!(raw_body, headers)
    secret = connection.webhook_secret
    return if secret.blank?

    signature = headers['X-Hub-Signature'].to_s.delete_prefix('sha256=')
    return if ActiveSupport::SecurityUtils.secure_compare(OpenSSL::HMAC.hexdigest('SHA256', secret, raw_body), signature)

    raise CustomExceptions::TicketSource::AuthError, 'Invalid webhook signature'
  end

  def parse_webhook(payload)
    event = payload['webhookEvent'].to_s
    external_id = payload.dig('issue', 'id') || payload.dig('comment', 'self').to_s[%r{/issue/(\d+)/}, 1]
    return { type: :ignored } if external_id.blank?
    return { type: :ticket_deleted, external_id: external_id } if event == 'jira:issue_deleted'
    return { type: :ticket_changed, external_id: external_id } if WEBHOOK_CHANGE_EVENTS.include?(event)

    { type: :ignored }
  end

  def in_scope?(external)
    external.key.to_s.start_with?("#{project_key}-")
  end

  def test_connection
    me = client.get('/rest/api/3/myself')
    project = client.get("/rest/api/3/project/#{project_key}")
    { display_name: me['displayName'], account_id: me['accountId'], time_zone: me['timeZone'], project: project['name'] }
  end

  def statuses
    client.get("/rest/api/3/project/#{project_key}/statuses").flat_map { |type| type['statuses'] }.uniq { |status| status['id'] }.map do |status|
      { id: status['id'], name: status['name'], category: status.dig('statusCategory', 'key') }
    end
  end

  def fetch_ticket(external_id)
    build_ticket(client.get("/rest/api/3/issue/#{external_id}", fields: ISSUE_FIELDS.join(',')))
  end

  def each_ticket_updated_since(time)
    jql = ["project = \"#{project_key}\"", time && "updated >= \"#{time.in_time_zone(time_zone).strftime('%Y/%m/%d %H:%M')}\""].compact.join(' AND ')
    page_token = nil
    loop do
      body = { jql: "#{jql} ORDER BY updated ASC", fields: ISSUE_FIELDS, maxResults: SEARCH_PAGE_SIZE, nextPageToken: page_token }.compact
      page = client.post('/rest/api/3/search/jql', body)
      page['issues'].each { |issue| yield build_ticket(issue) }
      page_token = page['nextPageToken']
      break if page['isLast'] || page_token.blank?
    end
  end

  def create_ticket(ticket)
    fields = { project: { key: project_key }, issuetype: { id: issue_type_id }, summary: ticket.title }
    fields[:description] = to_adf(ticket.description) if ticket.description.present?
    fetch_ticket(client.post('/rest/api/3/issue', fields: fields)['id'])
  end

  def update_ticket(external_id, title: nil, description: nil)
    fields = {}
    fields[:summary] = title unless title.nil?
    fields[:description] = description.empty? ? nil : to_adf(description) unless description.nil?
    client.put("/rest/api/3/issue/#{external_id}", fields: fields)
  end

  def add_comment(external_id, text)
    client.post("/rest/api/3/issue/#{external_id}/comment", body: to_adf(text))['id']
  end

  def add_attachment(external_id, filename, _content_type, io)
    client.post_file("/rest/api/3/issue/#{external_id}/attachments", filename, io).first['id']
  end

  def download_attachment(attachment)
    client.download(attachment[:content_url])
  end

  def canonical_text(text)
    TicketSources::Jira::AdfConverter.to_text(to_adf(text))
  end

  private

  def client
    @client ||= TicketSources::Jira::Client.new(site: credentials['site'], email: credentials['email'], api_token: credentials['api_token'])
  end

  def credentials
    connection.credential_values
  end

  def project_key
    connection.settings.fetch('project_key')
  end

  def time_zone
    connection.settings['time_zone'] || 'UTC'
  end

  def issue_type_id
    connection.settings['issue_type_id'] || default_issue_type_id
  end

  def default_issue_type_id
    types = client.get("/rest/api/3/issue/createmeta/#{project_key}/issuetypes")['issueTypes'].reject { |type| type['subtask'] }
    (types.find { |type| type['name'] == 'Task' } || types.first)['id']
  end

  def to_adf(text)
    TicketSources::Jira::AdfConverter.from_text(text)
  end

  def build_ticket(issue)
    fields = issue['fields']
    TicketSources::ExternalTicket.new(
      id: issue['id'], key: issue['key'], url: "#{client.base_url}/browse/#{issue['key']}",
      title: fields['summary'], description: TicketSources::Jira::AdfConverter.to_text(fields['description']),
      status: { id: fields.dig('status', 'id'), name: fields.dig('status', 'name'), category: fields.dig('status', 'statusCategory', 'key') },
      assignee: fields['assignee'] && { id: fields['assignee']['accountId'], name: fields['assignee']['displayName'] },
      updated_at: Time.zone.parse(fields['updated']), comments: build_comments(issue), attachments: build_attachments(fields)
    )
  end

  def build_comments(issue)
    embedded = issue.dig('fields', 'comment')
    comments = embedded['comments']
    while comments.size < embedded['total']
      page = client.get("/rest/api/3/issue/#{issue['id']}/comment", startAt: comments.size, maxResults: COMMENT_PAGE_SIZE)
      break if page['comments'].empty?

      comments += page['comments']
    end
    comments.map do |comment|
      { id: comment['id'], body: TicketSources::Jira::AdfConverter.to_text(comment['body']),
        author: comment.dig('author', 'displayName'), created_at: Time.zone.parse(comment['created']) }
    end
  end

  def build_attachments(fields)
    fields['attachment'].map do |attachment|
      { id: attachment['id'], filename: attachment['filename'], mime_type: attachment['mimeType'], size: attachment['size'],
        content_url: attachment['content'] }
    end
  end
end
