class V2::Reports::ConversationStatusBuilder
  include DateRangeHelper

  DEFAULT_GROUP_BY = 'day'.freeze
  PERMITTED_GROUP_BY = %w[day week month year].freeze
  STATUSES = Conversation.statuses.keys.freeze
  DIMENSIONS = { 'inbox' => :inbox_id, 'assignee' => :assignee_id }.freeze

  attr_reader :account, :params

  def initialize(account, params)
    @account = account
    @params = params
    @timezone = ActiveSupport::TimeZone[(params[:timezone_offset] || 0).to_f]
  end

  def build
    { totals: totals, timeline: timeline, breakdown: breakdown }
  end

  private

  def conversations
    @conversations ||= account.conversations.unscope(:order).where(created_at: range)
  end

  def blank_counts
    STATUSES.index_with(0)
  end

  def totals
    counts = conversations.group(:status).count
    blank_counts.merge(counts).merge('total' => counts.values.sum)
  end

  def timeline
    buckets = conversations.group(:status).group_by_period(
      params[:group_by].presence || DEFAULT_GROUP_BY,
      :created_at,
      default_value: 0,
      range: range,
      permit: PERMITTED_GROUP_BY,
      time_zone: @timezone
    ).count

    rows = buckets.each_with_object({}) do |((status, bucket), count), acc|
      row = acc[bucket] ||= blank_counts.merge('timestamp' => bucket.in_time_zone(@timezone).to_i)
      row[status] = count
    end

    rows.values.sort_by { |row| row['timestamp'] }
  end

  def breakdown
    rows = conversations.group(DIMENSIONS.fetch(dimension), :status).count.each_with_object({}) do |((key, status), count), acc|
      row = acc[key] ||= blank_counts.merge('id' => key, 'total' => 0)
      row[status] = count
      row['total'] += count
    end

    names = names_for(rows.keys.compact)
    rows.values.map { |row| row.merge('name' => names[row['id']]) }.sort_by { |row| -row['total'] }
  end

  def dimension
    params[:dimension].presence || 'inbox'
  end

  def names_for(ids)
    scope = dimension == 'inbox' ? account.inboxes : account.users
    scope.where(id: ids).pluck(:id, :name).to_h
  end
end
