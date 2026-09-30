require 'rails_helper'

RSpec.describe Tekomi::Llm::CallEmotionAnalysisSchema do
  it 'exposes exactly five complete emotion labels' do
    expect(described_class::LABELS).to eq(['buồn', 'trung tính', 'vui', 'khó chịu', 'gay gắt'])
  end
end
