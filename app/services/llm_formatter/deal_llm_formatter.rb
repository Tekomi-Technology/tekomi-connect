class LlmFormatter::DealLlmFormatter < LlmFormatter::DefaultLlmFormatter
  def format(*)
    sections = []
    sections << "Deal ID: ##{@record.id}"
    sections << 'Deal Attributes:'
    sections << build_attributes
    sections.join("\n")
  end

  private

  def build_attributes
    attributes = []
    attributes << "Name: #{@record.name}"
    attributes << "Value: #{formatted_value}"
    attributes << "Pipeline: #{@record.pipeline.name}"
    attributes << "Stage: #{@record.stage.name} (#{@record.stage.stage_type})"
    attributes << "Assignee: #{@record.assignee&.name || 'Unassigned'}"
    attributes << "Contact: #{contact_description}"
    attributes << "Expected close date: #{@record.expected_close_date || 'Not set'}"
    attributes << "Closed at: #{@record.closed_at || 'Still open'}"
    attributes << "Created at: #{@record.created_at}"
    attributes.concat(custom_attributes)
    attributes.join("\n")
  end

  def formatted_value
    return 'Not set' if @record.value.blank?

    "#{ActiveSupport::NumberHelper.number_to_delimited(@record.value)} VND"
  end

  def contact_description
    return 'No contact' if @record.contact.blank?

    "#{@record.contact.name} (Contact ID: ##{@record.contact_id})"
  end

  def custom_attributes
    @record.account.custom_attribute_definitions.with_attribute_model('deal_attribute').map do |attribute|
      "#{attribute.attribute_display_name}: #{@record.custom_attributes[attribute.attribute_key]}"
    end
  end
end
