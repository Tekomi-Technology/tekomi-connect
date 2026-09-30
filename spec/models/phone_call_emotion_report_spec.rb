require 'rails_helper'

RSpec.describe PhoneCallEmotionReport do
  describe '.normalize_emotion_label' do
    it 'normalizes every supported emotion and common model aliases' do
      expectations = {
        'vui' => 'vui',
        'Vui vẻ' => 'vui',
        'positive' => 'vui',
        'trung tính' => 'trung tính',
        'TRUNG TINH' => 'trung tính',
        'trung' => 'trung tính',
        'neutral' => 'trung tính',
        'buồn' => 'buồn',
        'BUON' => 'buồn',
        'sad' => 'buồn',
        'khó' => 'khó chịu',
        'chịu' => 'khó chịu',
        'Khó chịu' => 'khó chịu',
        'kho chiu' => 'khó chịu',
        'frustrated' => 'khó chịu',
        'annoyed' => 'khó chịu',
        'gay gắt' => 'gay gắt',
        'gay' => 'gay gắt',
        'gắt' => 'gay gắt',
        'GAY GAT' => 'gay gắt',
        'angry' => 'gay gắt'
      }

      expectations.each do |input, expected|
        expect(described_class.normalize_emotion_label(input)).to eq(expected), "expected #{input.inspect} to normalize"
      end
    end
  end

  describe '.emotion_filter_values' do
    it 'includes old split labels so historical reports remain filterable' do
      expect(described_class.emotion_filter_values('khó chịu')).to include('khó chịu', 'khó', 'chịu', 'kho', 'kho chiu')
      expect(described_class.emotion_filter_values('gay gắt')).to include('gay gắt', 'gay', 'gắt', 'gay gat')
    end
  end

  describe 'emotion colors' do
    it 'assigns a distinct color to every supported emotion' do
      colors = described_class::EMOTION_COLORS.values

      expect(described_class::EMOTION_COLORS.keys).to contain_exactly('vui', 'trung tính', 'buồn', 'khó chịu', 'gay gắt')
      expect(colors.uniq.size).to eq(colors.size)
    end

    it 'normalizes a short label before assigning its color' do
      report = described_class.new(emotion: 'khó')

      report.valid?

      expect(report.emotion).to eq('khó chịu')
      expect(report.emotion_color).to eq('orange')
    end
  end
end
