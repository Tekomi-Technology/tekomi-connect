class Tekomi::Llm::DealFieldExtractionSchema < RubyLLM::Schema
  FIELDS_DESCRIPTION = 'One entry per custom field you can fill from the conversations. ' \
                       'Leave the array empty when the conversations say nothing about any field.'
  KEY_DESCRIPTION = 'The key of the field, copied exactly from the field list given to you.'
  VALUE_DESCRIPTION = 'The value to store, written as text. Use YYYY-MM-DD for dates, true or false for checkboxes, ' \
                      'digits only for numbers, and one of the allowed options for list fields.'
  REASON_DESCRIPTION = 'One short sentence quoting what in the conversation gives this value.'

  array :fields, description: FIELDS_DESCRIPTION, max_items: 20 do
    object do
      string :attribute_key, description: KEY_DESCRIPTION, max_length: 100
      string :value, description: VALUE_DESCRIPTION, max_length: 200
      string :reason, description: REASON_DESCRIPTION, max_length: 200
    end
  end
end
