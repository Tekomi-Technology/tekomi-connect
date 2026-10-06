class TenantBranding::ProfileResolver
  def self.resolve(hostname)
    subdomain, domain = hostname.to_s.downcase.split('.', 2)
    return if subdomain.blank? || domain != TenantBrandingProfile.base_domain

    TenantBrandingProfile.find_by(subdomain: subdomain)
  end
end
