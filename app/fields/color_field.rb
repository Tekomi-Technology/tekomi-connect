require 'administrate/field/base'

class ColorField < Administrate::Field::String
  def palette
    options.fetch(:palette)
  end

  # Color the dashboard falls back to when the field is left blank; nil for required colors.
  def default_color
    options[:default_color]
  end

  def contrast_with
    options[:contrast_with]
  end

  def preview?
    options.fetch(:preview, false)
  end
end
