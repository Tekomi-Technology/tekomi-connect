# Counts calls and call minutes against the account license.
# Calls are counted when created; minutes once, when the call first reaches a terminal status.
module Licensing::MeteredCall
  extend ActiveSupport::Concern

  METERED_FLAG = 'licensing_minutes_metered'.freeze

  included do
    after_create_commit :licensing_record_call
    after_update_commit :licensing_record_minutes
  end

  private

  def licensing_record_call
    Licensing::Guard.new(account).consume!(:calls)
  rescue StandardError => e
    Rails.logger.error("[licensing] failed to record call for account #{account_id}: #{e.message}")
  end

  def licensing_record_minutes
    return unless saved_change_to_status? && terminal?
    return if licensing_store[METERED_FLAG]

    minutes = (duration_seconds.to_i / 60.0).ceil
    Licensing::Guard.new(account).consume!(:call_minutes, minutes)
    licensing_mark_metered
  rescue StandardError => e
    Rails.logger.error("[licensing] failed to record minutes for account #{account_id}: #{e.message}")
  end

  def licensing_store_column
    self.class.column_names.include?('metadata') ? :metadata : :meta
  end

  def licensing_store
    self[licensing_store_column] || {}
  end

  def licensing_mark_metered
    # rubocop:disable Rails/SkipsModelValidations
    update_column(licensing_store_column, licensing_store.merge(METERED_FLAG => true))
    # rubocop:enable Rails/SkipsModelValidations
  end
end
