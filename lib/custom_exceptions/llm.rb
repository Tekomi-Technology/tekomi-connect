module CustomExceptions::Llm
  class FeatureNotConfigured < CustomExceptions::Base
    def message
      I18n.t('errors.llm.feature_not_configured', feature: @data[:feature])
    end
  end

  class TenantProviderNotConfigured < FeatureNotConfigured
    def message
      I18n.t('errors.llm.tenant_provider_not_configured', provider: @data[:provider])
    end
  end
end
