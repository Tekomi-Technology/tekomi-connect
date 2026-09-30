class Tekomi::Llm::CallEmotionAnalysisSchema < RubyLLM::Schema
  LABELS = ['buồn', 'trung tính', 'vui', 'khó chịu', 'gay gắt'].freeze

  string :label,
         description: 'The single most prominent customer emotion in the transcript.',
         enum: LABELS
  string :reason,
         description: 'A short Vietnamese reason based only on explicit evidence in the transcript.',
         max_length: 300
end
