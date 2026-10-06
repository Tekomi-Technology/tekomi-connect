require 'ipaddr'

class TenantBrandingProfile < ApplicationRecord
  PROVISIONING_STATUSES = %w[pending provisioning active failed].freeze
  RESERVED_SUBDOMAINS = %w[api app mail smtp www].freeze

  belongs_to :account

  has_one_attached :logo
  has_one_attached :logo_dark
  has_one_attached :favicon

  before_validation :normalize_subdomain

  validates :account_id, uniqueness: true
  validates :brand_name, :origin_ip, :subdomain, presence: true
  validates :primary_color, format: { with: /\A#[0-9A-F]{6}\z/i }
  validates :provisioning_status, inclusion: { in: PROVISIONING_STATUSES }
  validates :subdomain,
            format: { with: /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/ },
            exclusion: { in: RESERVED_SUBDOMAINS },
            uniqueness: { case_sensitive: false }
  validate :origin_ip_must_be_ipv4
  validate :hostname_must_not_be_canonical
  validate :hostname_must_not_conflict_with_help_center
  validate :branding_assets_must_be_images

  after_commit :enqueue_dns_provisioning, on: %i[create update], if: :dns_provisioning_required?

  scope :enabled, -> { where(enabled: true) }

  def hostname
    "#{subdomain}.#{self.class.base_domain}"
  end

  def primary_color_rgb
    primary_color.delete_prefix('#').scan(/../).map { |component| component.to_i(16) }.join(' ')
  end

  def self.base_domain
    ENV.fetch('TENANT_BRANDING_BASE_DOMAIN', 'techxanh.com').downcase
  end

  private

  def normalize_subdomain
    value = subdomain.to_s.strip.downcase
    suffix = ".#{self.class.base_domain}"
    self.subdomain = value.delete_suffix(suffix)
  end

  def origin_ip_must_be_ipv4
    address = IPAddr.new(origin_ip.to_s)
    errors.add(:origin_ip, 'must be a public IPv4 address') unless address.ipv4? && !address.private? && !address.loopback?
  rescue IPAddr::InvalidAddressError
    errors.add(:origin_ip, 'must be a valid IPv4 address')
  end

  def hostname_must_not_conflict_with_help_center
    errors.add(:subdomain, 'is already used by a Help Center custom domain') if Portal.exists?(custom_domain: hostname)
  end

  def hostname_must_not_be_canonical
    canonical_host = URI.parse(ENV.fetch('FRONTEND_URL', '')).host
    errors.add(:subdomain, 'is reserved by the canonical frontend') if canonical_host == hostname
  rescue URI::InvalidURIError
    nil
  end

  def branding_assets_must_be_images
    %i[logo logo_dark favicon].each do |attachment_name|
      attachment = public_send(attachment_name)
      next unless attachment.attached?

      errors.add(attachment_name, 'must be smaller than 5 MB') if attachment.byte_size > 5.megabytes
      next if attachment.content_type.in?(%w[image/png image/webp image/jpeg image/svg+xml image/x-icon])

      errors.add(attachment_name, 'must be a PNG, WebP, JPEG, SVG, or ICO image')
    end
  end

  def dns_provisioning_required?
    enabled? && (previous_changes.key?('id') || previous_changes.keys.intersect?(%w[subdomain origin_ip enabled]))
  end

  def enqueue_dns_provisioning
    TenantBranding::ProvisionDnsJob.perform_later(id)
  end
end
