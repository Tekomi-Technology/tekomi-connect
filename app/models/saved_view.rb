class SavedView < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline, optional: true

  enum :object_type, { deal: 0 }, validate: true
  enum :view_type, { table: 0, kanban: 1, calendar: 2, list: 3 }, validate: true

  validates :name, presence: true
  validate :pipeline_belongs_to_account

  before_create :append_position

  private

  def append_position
    self.position = (account.saved_views.where(object_type: object_type).maximum(:position) || -1) + 1
  end

  def pipeline_belongs_to_account
    errors.add(:pipeline, :invalid) if pipeline && pipeline.account_id != account_id
  end
end
