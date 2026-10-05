require 'sidekiq/api'

class SuperAdmin::DashboardController < SuperAdmin::ApplicationController
  WINDOW = 30.days
  ACTIVITY_LIMIT = 8
  TOP_CHANNELS = 6

  CHANNEL_LABELS = {
    'Channel::WebWidget' => 'Website Livechat',
    'Channel::FacebookPage' => 'Facebook Messenger',
    'Channel::Instagram' => 'Instagram',
    'Channel::ZaloOa' => 'Zalo OA',
    'Channel::ZaloPersonal' => 'Zalo Personal',
    'Channel::Phone' => 'Phone',
    'Channel::Email' => 'Email',
    'Channel::Telegram' => 'Telegram',
    'Channel::Line' => 'LINE',
    'Channel::Sms' => 'SMS',
    'Channel::TwilioSms' => 'Twilio SMS',
    'Channel::Whatsapp' => 'WhatsApp',
    'Channel::Tiktok' => 'TikTok',
    'Channel::Api' => 'API',
    'Channel::TwitterProfile' => 'X'
  }.freeze

  def index
    respond_to do |format|
      format.html
      format.json { render json: dashboard_stats }
    end
  end

  private

  # The aggregates scan large tables, so they stay cached. System status is the
  # part an operator checks for a live answer, so it is read on every request.
  def dashboard_stats
    analytics.merge(system: system_status, generatedAt: Time.current.iso8601)
  end

  def analytics
    Rails.cache.fetch('super_admin:dashboard_stats', expires_in: 30.minutes) do
      {
        version: Chatwoot.config[:version],
        metrics: metrics,
        chart: chart,
        channels: channel_distribution,
        activity: recent_activity
      }
    end
  end

  def metrics
    {
      accounts: {
        value: Account.count,
        delta: delta_for(Account),
        detail: { active: Account.active.count }
      },
      users: {
        value: User.count,
        delta: delta_for(User),
        detail: { recent: User.where(last_sign_in_at: 7.days.ago..).count }
      },
      inboxes: {
        value: Inbox.count,
        delta: delta_for(Inbox),
        detail: { channels: Inbox.distinct.count(:channel_type) }
      },
      conversations: {
        value: conversations_count_estimate,
        delta: delta_for(Conversation.unscoped),
        detail: { peak: daily_totals.values.max.to_i }
      }
    }
  end

  # Percentage change between the last window and the one before it. Nil when
  # the earlier window is empty, since there is no baseline to compare against.
  def delta_for(scope)
    current = scope.where(created_at: WINDOW.ago..).count
    previous = scope.where(created_at: (WINDOW * 2).ago...WINDOW.ago).count
    return if previous.zero?

    (((current - previous) / previous.to_f) * 100).round(1)
  end

  def chart
    categories = daily_totals.keys.map(&:to_s)
    all = { id: 'all', label: I18n.t('super_admin.dashboard.all_channels'), data: daily_totals.values }

    { categories: categories, series: [all] + channel_series(categories) }
  end

  def channel_series(categories)
    grouped = Conversation.unscoped.joins(:inbox)
                          .group('inboxes.channel_type')
                          .group_by_day('conversations.created_at', range: window_range)
                          .count

    top_channel_types.map do |channel_type|
      {
        id: channel_type,
        label: channel_label(channel_type),
        data: categories.map { |day| grouped[[channel_type, Date.parse(day)]].to_i }
      }
    end
  end

  def channel_distribution
    total = channel_totals.values.sum
    channel_totals.map do |channel_type, count|
      {
        id: channel_type,
        label: channel_label(channel_type),
        conversations: count,
        share: total.zero? ? 0 : ((count / total.to_f) * 100).round(1)
      }
    end
  end

  def system_status
    {
      postgres: ActiveRecord::Base.connection.active?,
      migrationsPending: ActiveRecord::MigrationContext.new(ActiveRecord::Migrator.migrations_paths).needs_migration?,
      redis: redis_status,
      sidekiq: sidekiq_status,
      push: {
        subscriptions: NotificationSubscription.count,
        byType: NotificationSubscription.group(:subscription_type).count
      }
    }
  end

  def redis_status
    redis = Redis.new(Redis::Config.app)
    info = redis.info
    { alive: true, version: info['redis_version'], clients: info['connected_clients'].to_i, memory: info['used_memory_human'] }
  rescue Redis::CannotConnectError
    { alive: false }
  end

  def sidekiq_status
    stats = Sidekiq::Stats.new
    queues = Sidekiq::Queue.all
    {
      processes: Sidekiq::ProcessSet.new.size,
      busy: Sidekiq::Workers.new.size,
      enqueued: stats.enqueued,
      retrySize: stats.retry_size,
      deadSize: stats.dead_size,
      failed: stats.failed,
      processed: stats.processed,
      latency: queues.map(&:latency).max.to_f.round(2)
    }
  end

  def recent_activity
    Enterprise::AuditLog.order(created_at: :desc).limit(ACTIVITY_LIMIT).map do |audit|
      {
        id: audit.id,
        action: audit.action,
        type: audit.auditable_type,
        user: audit.username.presence,
        at: audit.created_at.iso8601
      }
    end
  end

  def daily_totals
    @daily_totals ||= Conversation.unscoped.group_by_day(:created_at, range: window_range).count
  end

  def channel_totals
    @channel_totals ||= Conversation.unscoped.joins(:inbox)
                                    .where(created_at: window_range)
                                    .group('inboxes.channel_type')
                                    .count
                                    .sort_by { |_type, count| -count }
                                    .first(TOP_CHANNELS)
                                    .to_h
  end

  def top_channel_types
    channel_totals.keys
  end

  def channel_label(channel_type)
    CHANNEL_LABELS.fetch(channel_type) { channel_type.to_s.demodulize.titleize }
  end

  def window_range
    WINDOW.ago..2.seconds.ago
  end

  # Exact COUNT(*) scans the whole table; the planner estimate is instant
  # and close enough for dashboard display.
  def conversations_count_estimate
    estimate = ActiveRecord::Base.connection.select_value(
      "SELECT reltuples::bigint FROM pg_class WHERE relname = 'conversations'"
    ).to_i
    # reltuples is -1 until the table is first vacuumed/analyzed
    estimate.negative? ? Conversation.count : estimate
  end
end
