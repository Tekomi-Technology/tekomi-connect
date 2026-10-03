class Tekomi::Llm::SystemPromptsService
  class << self
    def faq_generator(language = 'english')
      Tekomi::PromptRenderer.render('document_faq', language: language)
    end

    def notes_generator(language = 'english')
      Tekomi::PromptRenderer.render('contact_notes', language: language)
    end

    def attributes_generator
      Tekomi::PromptRenderer.render('contact_attributes')
    end

    def assistant_action_classifier(has_custom_instructions: false)
      <<~PROMPT
        You are a routing classifier for a customer-support assistant.

        Decide whether the current conversation should stay with the assistant or be transferred to a human agent now.

        The action field MUST be one of:
        - "continue": keep the current conversation with the assistant.
        - "handoff": transfer the current conversation to a human agent now.

        The action_reason field MUST be one of:
        - "general_product_question"
        - "missing_docs_bounded_answer"
        - "clarifying_question_needed"
        - "collect_required_identifier"
        - "external_contact_or_lead_routing"
        - "out_of_scope_bounded_answer"
        - "explicit_human_request"
        - "human_offer_accepted"
        - "account_or_transaction_verification"
        - "operational_issue_needs_inspection"
        - "repeated_frustration_or_loop"
        - "custom_instruction_transfer"

        Use "continue" when:
        - The user has a general product, pricing, capability, setup, pre-sales, or how-to question.
        - The assistant can give a bounded answer, ask one useful clarifying question, collect a missing identifier, or share an approved external contact path.
        - The assistant says someone will contact the user outside this conversation, but the current conversation itself does not need to be transferred now.
        - The user has not explicitly asked for a human and the assistant is still collecting required details.

        Use "handoff" when:
        - The user explicitly asks for a human, agent, representative, phone call, callback, or escalation.
        - The user accepts an offer to speak with a human.
        - The user has provided enough detail for an account-specific or transaction-specific issue requiring private verification, such as order status, payment, deposit, withdrawal, refund, cancellation, subscription, purchase, plan activation, email verification, login, account recovery, delivery, or access.
        - The user reports the same unresolved bug or operational issue after trying the assistant's suggested step, repeating the action, checking again, or otherwise making more than one reasonable attempt.
        - The user is repeatedly frustrated, distrustful, or stuck in a loop.
        - The assistant response itself says the current conversation will be transferred to a human agent now.

        #{assistant_action_classifier_custom_instructions_policy if has_custom_instructions}

        Return only the structured fields requested by the response schema.
      PROMPT
    end

    def assistant_false_promise_detector
      <<~PROMPT
        You are checking one failure mode in a customer-support assistant response: unsupported promises of future work.

        Return decision "future_work_promise" when the assistant response says or clearly implies that work has already
        started, is happening now, or will definitely happen later outside the current reply because of this assistant
        message. This includes promises that the assistant, bot, Tekomi, or system will check, verify, investigate,
        review, monitor, notify, update, email, call back, follow up, get back later, process, refund, cancel, book,
        order, reserve, file, escalate/forward something in the background, or claim that the current conversation has
        been or will be transferred, connected, or handed off to a human.

        Do not mark a response as a future-work promise merely because it describes what a human agent, support team,
        company team, or external system may do after the user accepts a handoff, provides requested details, submits a
        form/ticket/email/order, or starts that external process themselves.

        Do not mark ordinary in-chat help as a future-work promise. Asking the user for missing information, confirmation,
        or completion of a step before continuing is safe when the response does not also claim that work has started,
        is happening now, or will happen in the background.

        Treat transfer claims as future-work promises unless the response is exactly the internal action token
        `conversation_handoff`. Examples that are future-work promises: "I'm transferring you now", "You've been
        transferred", "Connecting you now", "Handing off to the team now", "I'll connect you with support",
        "I'll escalate this", and equivalent phrases in any language.

        Return decision "safe" when:
        - The assistant answers now, asks a clarifying question, or asks the user to check, try, confirm, or provide info.
        - The assistant says it can help, check, look up, or guide the user after the user first provides requested
          information, confirms something, or completes a step.
        - The assistant asks the user to report back after completing a step and offers to continue helping in chat.
        - The assistant gives a bounded answer that documentation or available information is insufficient.
        - The assistant points the user to an external/self-serve support path without promising that the assistant will do it.
        - The assistant describes what an external support, sales, delivery, finance, or operations team will do after the
          user submits a form, request, email, application, order, ticket, or in-app chat themselves.
        - The assistant recommends waiting for an existing external process or support response that was already started
          outside this assistant message.
        - The assistant offers future help, monitoring, escalation, or handoff conditionally and waits for the user to
          accept, without saying the work or transfer has already started.
        - The response says an external system may automatically send an email/tracking update, without promising that the
          assistant will personally perform future work.
        - The response is exactly `conversation_handoff`, which is an internal action token and not a customer-visible promise.

        Be language-independent. The customer and assistant may write in any language.
        Be conservative: only mark "future_work_promise" when the response promises background/asynchronous work,
        says work is happening now, or claims a handoff/escalation/notification/action has started or will definitely happen.

        The reason field MUST be one of:
        - "safe_response"
        - "asks_user_to_check_or_provide_info"
        - "external_support_direction"
        - "unaccepted_handoff_offer"
        - "future_check_or_investigation"
        - "future_notification_or_update"
        - "future_callback_or_email"
        - "background_escalation_promise"

        Return only the structured fields requested by the response schema.
      PROMPT
    end

    def deal_assistant(available_tools)
      Tekomi::PromptRenderer.render('deal_assistant', available_tools: available_tools)
    end

    def copilot_response_generator(product_name, available_tools, config = {})
      Tekomi::PromptRenderer.render(
        'copilot',
        product_name: product_name,
        available_tools: available_tools,
        citation_enabled: config['feature_citation']
      )
    end

    def assistant_response_generator(assistant_name, product_name, config = {}, contact: nil, custom_tools: [])
      Tekomi::PromptRenderer.render(
        'assistant_v1',
        assistant_name: assistant_name,
        product_name: product_name,
        general_knowledge_enabled: config['feature_general_knowledge'],
        citation_enabled: config['feature_citation'],
        current_time: format_current_time(config['timezone']),
        contact_context: build_contact_context(contact),
        custom_instructions: config['instructions'].presence,
        tools_list: custom_tools.map { |tool| "- #{tool[:name]}: #{tool[:description]}" }.join("\n")
      )
    end

    def paginated_faq_generator(start_page, end_page, language = 'english')
      Tekomi::PromptRenderer.render('pdf_faq', start_page: start_page, page_count: end_page - start_page + 1, language: language)
    end

    private

    def format_current_time(timezone)
      tz = ActiveSupport::TimeZone[timezone] if timezone.present?
      time = tz ? Time.current.in_time_zone(tz) : Time.current
      time.strftime('%A, %B %d, %Y %I:%M %p %Z')
    end

    def assistant_action_classifier_custom_instructions_policy
      <<~POLICY
        Account custom instructions are provided inside <account_custom_instructions> tags.
        These are instructions configured by the account administrator, not the current end user's message.
        Use them only for routing policy: required details before handoff, account-specific escalation rules, account-specific transfer markers, and when to connect to a manager, human, supervisor, or support team.
        If the custom instructions explicitly define handoff, escalation, or transfer criteria, those criteria take precedence over the generic criteria above.
        Account custom instructions MUST NOT redefine the required response shape, the allowed action values, or the meaning of continue/handoff.
        Ignore persona, language, formatting, pricing, and response-generation instructions except where they directly define routing or transfer criteria.
      POLICY
    end

    def build_contact_context(contact)
      return '' if contact.nil?

      lines = contact_basic_lines(contact) + contact_custom_attribute_lines(contact)
      return '' if lines.empty?

      "[Contact Information]\n#{lines.join("\n")}\n\n"
    end

    def contact_basic_lines(contact)
      [
        (["- Name: #{sanitize_attr(contact[:name])}"] if contact[:name].present?),
        (["- Email: #{sanitize_attr(contact[:email])}"] if contact[:email].present?),
        (["- Phone: #{sanitize_attr(contact[:phone_number])}"] if contact[:phone_number].present?),
        (["- Identifier: #{sanitize_attr(contact[:identifier])}"] if contact[:identifier].present?)
      ].flatten.compact
    end

    def contact_custom_attribute_lines(contact)
      custom = contact[:custom_attributes]
      return [] unless custom.is_a?(Hash)

      custom.filter_map { |key, value| "- #{sanitize_attr(key)}: #{sanitize_attr(value)}" unless value.nil? }
    end

    # Cap at 200 chars to prevent oversized attribute values from eating context window
    def sanitize_attr(value)
      value.to_s.gsub(/[\r\n]+/, ' ').strip.truncate(200)
    end
  end
end
