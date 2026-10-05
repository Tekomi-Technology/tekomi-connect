# One person reaching us on several channels (Zalo, Facebook, phone, email) should be one contact.
# Contacts sharing a strong key — the same email, or the same phone number once normalized —
# are merged in the background as soon as that key is saved; see Contacts::AutoMergeService.
module IdentityMergeable
  extend ActiveSupport::Concern

  # PhoneNumberNormalizer's comparison key computed in SQL, so "0901…", "+84901…" and
  # "84 901 …" are found as one number in a single query instead of a Ruby scan.
  NORMALIZED_PHONE_SQL = "regexp_replace(regexp_replace(regexp_replace(contacts.phone_number, '[^0-9]', '', 'g'), '^84', ''), '^0', '')".freeze

  included do
    scope :with_normalized_phone, lambda { |phone_number|
      key = PhoneNumberNormalizer.normalize(phone_number)
      key.blank? ? none : where.not(phone_number: [nil, '']).where("#{NORMALIZED_PHONE_SQL} = ?", key)
    }

    after_commit :enqueue_auto_merge, on: [:create, :update], if: :strong_identity_saved?
  end

  private

  def strong_identity_saved?
    (saved_change_to_email? && email.present?) || (saved_change_to_phone_number? && phone_number.present?)
  end

  def enqueue_auto_merge
    Contacts::AutoMergeJob.perform_later(id)
  end
end
