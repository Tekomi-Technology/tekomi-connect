#!/usr/bin/env python3
"""Private Zipformer 30M transcription service for server-side call analysis."""

from __future__ import annotations

import io
import os
import threading
from pathlib import Path

import numpy as np
import soundfile as sf
from fastapi import FastAPI, File, HTTPException, UploadFile
from scipy.signal import resample_poly
from sherpa_onnx import OfflineRecognizer


MODEL_DIR = Path(os.environ.get("MODEL_DIR", "/models"))
ENCODER = os.environ.get("ASR_ENCODER", "encoder-epoch-20-avg-10.int8.onnx")
DECODER = os.environ.get("ASR_DECODER", "decoder-epoch-20-avg-10.int8.onnx")
JOINER = os.environ.get("ASR_JOINER", "joiner-epoch-20-avg-10.int8.onnx")
TOKENS = os.environ.get("ASR_TOKENS", "config.json")
BPE = os.environ.get("ASR_BPE", "bpe.model")


def load_audio(raw: bytes) -> tuple[np.ndarray, int]:
    try:
        audio, sample_rate = sf.read(io.BytesIO(raw), dtype="float32", always_2d=False)
    except Exception as exc:  # pragma: no cover - exercised by the running sidecar
        raise ValueError("Unable to decode audio") from exc

    if audio.ndim == 2:
        audio = audio.mean(axis=1)
    audio = np.asarray(audio, dtype=np.float32)
    if audio.size == 0 or not np.isfinite(audio).all():
        raise ValueError("Audio is empty or invalid")
    if sample_rate != 16_000:
        audio = resample_poly(audio, 16_000, sample_rate).astype(np.float32)
        sample_rate = 16_000
    peak = float(np.max(np.abs(audio)))
    if peak > 1.0:
        audio = audio / peak
    return audio, sample_rate


class ZipformerTranscriber:
    def __init__(self) -> None:
        self.recognizer: OfflineRecognizer | None = None
        self.error: str | None = None
        self.lock = threading.Lock()

    @property
    def ready(self) -> bool:
        return self.recognizer is not None

    def load(self) -> None:
        try:
            self.recognizer = OfflineRecognizer.from_transducer(
                encoder=str(MODEL_DIR / ENCODER),
                decoder=str(MODEL_DIR / DECODER),
                joiner=str(MODEL_DIR / JOINER),
                tokens=str(MODEL_DIR / TOKENS),
                bpe_vocab=str(MODEL_DIR / BPE),
                modeling_unit="bpe",
                num_threads=max(1, (os.cpu_count() or 2) - 1),
                sample_rate=16_000,
                feature_dim=80,
                decoding_method="greedy_search",
                provider="cpu",
            )
        except Exception as exc:  # surfaced by /health
            self.error = f"{type(exc).__name__}: {exc}"

    def transcribe(self, raw: bytes) -> dict[str, str]:
        if not self.ready:
            raise RuntimeError(self.error or "Zipformer is still loading")

        audio, sample_rate = load_audio(raw)
        with self.lock:
            stream = self.recognizer.create_stream()
            stream.accept_waveform(sample_rate, audio)
            self.recognizer.decode_stream(stream)
            transcript = str(stream.result.text).strip().lower()

        return {
            "transcript": transcript,
            "asr_model": "trung381/zip-30m",
            "asr_runtime": "sherpa-onnx-offline",
        }


engine = ZipformerTranscriber()
app = FastAPI(title="Chatwoot Zipformer transcription")


@app.on_event("startup")
def load_model() -> None:
    threading.Thread(target=engine.load, daemon=True, name="zipformer-loader").start()


@app.get("/health")
def health() -> dict[str, object]:
    return {"ready": engine.ready, "error": engine.error, "model": "trung381/zip-30m"}


@app.post("/transcribe")
def transcribe(file: UploadFile = File(...)) -> dict[str, str]:
    if not engine.ready:
        raise HTTPException(status_code=503, detail=engine.error or "Zipformer is still loading")
    raw = file.file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Audio is empty")
    try:
        return engine.transcribe(raw)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {type(exc).__name__}: {exc}") from exc
