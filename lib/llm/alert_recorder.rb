# frozen_string_literal: true

require 'digest'

module Llm
  class AlertRecorder
    DEDUPLICATION_WINDOW = 10.minutes
    MESSAGE_LIMIT = 2_000
    CATEGORIES = AiAlert::CATEGORIES.freeze

    class << self
      def record(account:, error:, feature: nil, provider: nil, status_code: nil, metadata: {})
        return if account.blank?

        details = classify(error, status_code: status_code)
        feature = feature.to_s.presence
        provider = provider.to_s.presence
        message = sanitize_message(error.message.presence || error.class.name)
        fingerprint = Digest::SHA256.hexdigest([feature, provider, details[:category], message].join('|'))
        now = Time.current
        alert = account.ai_alerts.where(fingerprint: fingerprint)
                        .where('last_seen_at >= ?', now - DEDUPLICATION_WINDOW).recent_first.first

        if alert
          alert.update!(
            occurrences: alert.occurrences + 1,
            last_seen_at: now,
            read_at: nil,
            status_code: details[:status_code] || alert.status_code,
            metadata: safe_metadata(metadata)
          )
          broadcast(alert, event_name: 'ai_alert.updated')
        else
          alert = account.ai_alerts.create!(
            category: details[:category],
            feature: feature,
            provider: provider,
            title: details[:title],
            message: message,
            fingerprint: fingerprint,
            status_code: details[:status_code],
            metadata: safe_metadata(metadata),
            last_seen_at: now
          )
          broadcast(alert, event_name: 'ai_alert.created')
        end

        alert
      rescue StandardError => e
        # A failure while recording telemetry must never hide the original AI failure.
        Rails.logger.error("[AI_ALERT] Could not record alert: #{e.class}: #{e.message}")
        nil
      end

      def broadcast(alert, event_name: 'ai_alert.updated')
        return if alert.blank?

        tokens = alert.account.administrators.where.not(pubsub_token: nil).pluck(:pubsub_token)
        return if tokens.blank?

        ActionCableBroadcastJob.perform_later(
          tokens,
          event_name,
          {
            ai_alert: alert.push_event_data,
            unread_count: alert.account.ai_alerts.unread.count,
            count: alert.account.ai_alerts.count,
            account_id: alert.account_id
          }
        )
      rescue StandardError => e
        Rails.logger.error("[AI_ALERT] Could not broadcast alert: #{e.class}: #{e.message}")
        nil
      end

      def broadcast_account(account, event_name, data = {})
        return if account.blank?

        tokens = account.administrators.where.not(pubsub_token: nil).pluck(:pubsub_token)
        return if tokens.blank?

        ActionCableBroadcastJob.perform_later(tokens, event_name, data.merge(account_id: account.id))
      rescue StandardError => e
        Rails.logger.error("[AI_ALERT] Could not broadcast account event: #{e.class}: #{e.message}")
        nil
      end

      private

      def classify(error, status_code: nil)
        message = [error.class.name, error.message].join(' ').downcase
        extracted_status = status_code || extract_status_code(error, message)

        if error.is_a?(CustomExceptions::Llm::TenantProviderNotConfigured) ||
           error.is_a?(CustomExceptions::Llm::FeatureNotConfigured) || message.match?(/not configured|missing.*provider|no .*api key/)
          { category: 'configuration', title: 'AI configuration is incomplete', status_code: extracted_status }
        elsif extracted_status.to_i == 401 || extracted_status.to_i == 403 ||
              message.match?(/unauthori[sz]ed|invalid.*(api )?key|authentication|credential/)
          { category: 'authentication', title: 'AI API key was rejected', status_code: extracted_status }
        elsif [402, 429].include?(extracted_status.to_i) ||
              message.match?(/rate.?limit|quota|credit|billing|insufficient funds|too many requests|limit exceeded/)
          { category: 'quota', title: 'AI provider limit or credits reached', status_code: extracted_status }
        elsif message.match?(/timeout|timed out|connection|network|econn|502|503|504|temporarily unavailable/)
          { category: 'availability', title: 'AI provider is temporarily unavailable', status_code: extracted_status }
        elsif error.class.name.to_s.start_with?('CustomExceptions::Llm')
          { category: 'provider', title: 'AI provider returned an error', status_code: extracted_status }
        else
          { category: 'unknown', title: 'AI request failed', status_code: extracted_status }
        end
      end

      def extract_status_code(error, message)
        direct_status = error.status if error.respond_to?(:status)
        return direct_status.to_i if direct_status.present?

        response = error.respond_to?(:response) ? error.response : nil
        response_status = if response.respond_to?(:status)
                            response.status
                          elsif response.respond_to?(:code)
                            response.code
                          else
                            response&.[](:status) || response&.[]('status')
                          end
        return response_status.to_i if response_status.present?

        message[/\b([1-5]\d{2})\b/, 1]&.to_i
      end

      def sanitize_message(message)
        message.to_s.gsub(/Bearer\s+[A-Za-z0-9._-]+/i, 'Bearer [REDACTED]')
                     .gsub(/(["']?api[_ -]?key["']?\s*[:=]\s*)[^,\s}]+/i, '\\1[REDACTED]')
                     .truncate(MESSAGE_LIMIT)
      end

      def safe_metadata(metadata)
        return {} unless metadata.respond_to?(:to_h)

        metadata.to_h.stringify_keys.except('api_key', 'authorization', 'token', 'secret')
      end
    end
  end
end
