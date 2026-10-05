require 'rails_helper'

RSpec.describe ConversationEmotionReport do
  describe 'emotion normalization' do
    it 'normalizes legacy partial labels and assigns the matching color' do
      report = described_class.new(emotion: 'khó')

      report.valid?

      expect(report.emotion).to eq('khó chịu')
      expect(report.emotion_color).to eq('orange')
      expect(report.emotion_tag).to eq('label' => 'khó chịu', 'color' => 'orange')
    end
  end
end
