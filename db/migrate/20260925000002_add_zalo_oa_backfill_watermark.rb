class AddZaloOaBackfillWatermark < ActiveRecord::Migration[7.2]
  def change
    add_column :channel_zalo_oa, :backfill_watermark_ms, :bigint, null: false, default: 0
  end
end
