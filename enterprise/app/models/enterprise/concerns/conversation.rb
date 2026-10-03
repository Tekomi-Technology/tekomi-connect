module Enterprise::Concerns::Conversation
  extend ActiveSupport::Concern

  included do
    belongs_to :sla_policy, optional: true
    has_one :applied_sla, dependent: :destroy_async
    has_many :sla_events, dependent: :destroy_async
    has_many :calls, dependent: :destroy_async
    has_many :tekomi_responses, class_name: 'Tekomi::AssistantResponse', dependent: :nullify, as: :documentable
    has_many :tekomi_faq_observations, class_name: 'Tekomi::FaqObservation', dependent: :delete_all
    has_many :conversation_outcomes, dependent: :destroy_async
    has_one :conversation_analysis, dependent: :destroy_async
    scope :with_sla_applicable_contact, -> { left_joins(:contact).where(contacts: { blocked: [false, nil] }) }

    before_validation :validate_sla_policy, if: -> { sla_policy_id_changed? }
    around_save :ensure_applied_sla_is_created, if: -> { sla_policy_id_changed? }
    after_save :start_sla_first_response_timer, if: -> { saved_change_to_status? && status_before_last_save == 'pending' }
  end

  def sla_applicable?
    !contact&.blocked?
  end

  private

  def validate_sla_policy
    # TODO: remove these validations once we figure out how to deal with these cases
    if sla_policy_id.nil? && changes[:sla_policy_id].first.present?
      errors.add(:sla_policy, 'cannot remove sla policy from conversation')
      return
    end

    unless sla_applicable?
      errors.add(:sla_policy, 'cannot be assigned to conversations with blocked contacts')
      return
    end

    if changes[:sla_policy_id].first.present?
      errors.add(:sla_policy, 'conversation already has a different sla')
      return
    end

    errors.add(:sla_policy, 'sla policy account mismatch') if sla_policy&.account_id != account_id
  end

  # Leaving pending for open or snoozed means a human took over from the bot (handoff or manual),
  # which is when the first-response SLA starts. A bot-resolved conversation never starts it.
  def start_sla_first_response_timer
    return unless open? || snoozed?
    return if applied_sla.blank? || applied_sla.frt_started_at.present?

    applied_sla.update!(frt_started_at: Time.current)
  end

  # handling inside a transaction to ensure applied sla record is also created
  def ensure_applied_sla_is_created
    ActiveRecord::Base.transaction do
      yield
      create_applied_sla(sla_policy_id: sla_policy_id) if applied_sla.blank?
    end
  rescue ActiveRecord::RecordInvalid
    raise ActiveRecord::Rollback
  end
end
