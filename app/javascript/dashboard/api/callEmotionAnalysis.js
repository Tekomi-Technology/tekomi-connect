const CALL_EMOTION_API_URL = 'https://192.168.1.97:8443/api/analyze';

const toMonoWav = audioBuffer => {
  const channelCount = audioBuffer.numberOfChannels;
  const frameCount = audioBuffer.length;
  const bytesPerSample = 2;
  const dataSize = frameCount * bytesPerSample;
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);

  const writeString = (offset, value) => {
    for (let index = 0; index < value.length; index += 1) {
      view.setUint8(offset + index, value.charCodeAt(index));
    }
  };

  writeString(0, 'RIFF');
  view.setUint32(4, 36 + dataSize, true);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, audioBuffer.sampleRate, true);
  view.setUint32(28, audioBuffer.sampleRate * bytesPerSample, true);
  view.setUint16(32, bytesPerSample, true);
  view.setUint16(34, 16, true);
  writeString(36, 'data');
  view.setUint32(40, dataSize, true);

  const channels = Array.from({ length: channelCount }, (_, index) =>
    audioBuffer.getChannelData(index)
  );
  let offset = 44;
  for (let frame = 0; frame < frameCount; frame += 1) {
    let sample = 0;
    channels.forEach(channel => {
      sample += channel[frame];
    });
    sample /= channelCount;
    const clipped = Math.max(-1, Math.min(1, sample));
    view.setInt16(
      offset,
      clipped < 0 ? clipped * 32768 : clipped * 32767,
      true
    );
    offset += bytesPerSample;
  }

  return new Blob([buffer], { type: 'audio/wav' });
};

const getRecordingBlob = async recordingUrl => {
  let audioUrl = recordingUrl;
  if (recordingUrl.startsWith('/api/')) {
    const response = await window.axios.get(recordingUrl, {
      params: { playback_url: true },
    });
    audioUrl = response.data.url;
  }

  const response = await fetch(audioUrl);
  if (!response.ok) throw new Error('Unable to download the call recording.');

  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) throw new Error('Audio conversion is not supported.');

  const context = new AudioContextClass();
  try {
    const audioBuffer = await context.decodeAudioData(
      await response.arrayBuffer()
    );
    return toMonoWav(audioBuffer);
  } finally {
    await context.close();
  }
};

const analyzeCallRecording = async recordingUrl => {
  const wav = await getRecordingBlob(recordingUrl);
  const formData = new FormData();
  formData.append('file', wav, 'call-recording.wav');

  const response = await fetch(CALL_EMOTION_API_URL, {
    method: 'POST',
    body: formData,
  });

  const result = await response.json();
  if (!response.ok) {
    throw new Error(result.detail || 'Call emotion analysis failed.');
  }

  return result;
};

export default analyzeCallRecording;
