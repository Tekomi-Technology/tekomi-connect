module PhoneNumberNormalizer
  module_function

  # VN-centric comparison key: strips formatting, the 84 country code and the
  # 0 trunk prefix, so "+84342387314", "0342387314" and "84 342 387 314" agree.
  def normalize(number)
    digits = number.to_s.gsub(/\D/, '')
    digits = digits.delete_prefix('84') if digits.start_with?('84')
    digits.delete_prefix('0')
  end
end
