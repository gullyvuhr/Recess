"""Generate original Recess Bell sounds from deterministic waveforms."""

from __future__ import annotations

import hashlib
import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SAMPLE_RATE = 44_100
SEED = 5_202


def _attack_release(time: float, duration: float, attack: float, release: float) -> float:
    attack_gain = min(1.0, time / attack)
    release_gain = min(1.0, max(0.0, duration - time) / release)
    return attack_gain * release_gain


def _normalize(samples: list[float], target_rms: float, peak_limit: float) -> list[float]:
    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    gain = target_rms / rms if rms else 0.0
    peak = max(abs(sample * gain) for sample in samples)
    if peak > peak_limit:
        gain *= peak_limit / peak
    return [sample * gain for sample in samples]


def _school_bell(duration: float = 1.5) -> list[float]:
    randomizer = random.Random(SEED)
    samples = []
    partials = ((732, 1.0, 3.0), (1117, 0.72, 3.8), (1564, 0.44, 4.8), (2191, 0.25, 6.0))
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        attack = min(1.0, time / 0.004)
        tone = sum(
            weight * math.sin(2 * math.pi * frequency * time + order * 0.31) * math.exp(-decay * time)
            for order, (frequency, weight, decay) in enumerate(partials)
        )
        strike = (randomizer.random() * 2 - 1) * math.exp(-95 * time) * 0.35
        samples.append(attack * tone + strike)
    return _normalize(samples, target_rms=0.13, peak_limit=0.86)


def _coach_whistle(duration: float = 0.75) -> list[float]:
    randomizer = random.Random(SEED + 1)
    samples = []
    previous_noise = 0.0
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        envelope = _attack_release(time, duration, 0.012, 0.065)
        vibrato = 1 + 0.0025 * math.sin(2 * math.pi * 27 * time)
        fundamental = math.sin(2 * math.pi * 3150 * vibrato * time)
        edge = math.sin(2 * math.pi * 6300 * vibrato * time + 0.2)
        noise = randomizer.random() * 2 - 1
        bright_noise = noise - 0.88 * previous_noise
        previous_noise = noise
        samples.append(envelope * (0.78 * fundamental + 0.18 * edge + 0.15 * bright_noise))
    return _normalize(samples, target_rms=0.17, peak_limit=0.88)


def _gentle_chime(duration: float = 1.8) -> list[float]:
    samples = []
    partials = ((659.25, 1.0, 2.5), (1318.5, 0.38, 3.5), (1977.8, 0.18, 4.8), (2637.0, 0.08, 6.2))
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        attack = min(1.0, time / 0.018)
        tone = sum(
            weight * math.sin(2 * math.pi * frequency * time + order * 0.18) * math.exp(-decay * time)
            for order, (frequency, weight, decay) in enumerate(partials)
        )
        samples.append(attack * tone)
    return _normalize(samples, target_rms=0.085, peak_limit=0.68)


def _write_wave(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = b"".join(struct.pack("<h", round(sample * 32767)) for sample in samples)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(frames)


def main() -> None:
    sounds = {
        "school_bell.wav": _school_bell(),
        "coach_whistle.wav": _coach_whistle(),
        "gentle_chime.wav": _gentle_chime(),
    }
    for filename, samples in sounds.items():
        canonical = ROOT / "assets/sounds" / filename
        _write_wave(canonical, samples)
        data = canonical.read_bytes()
        for destination in (
            ROOT / "android/app/src/main/res/raw" / filename,
            ROOT / "ios/Runner/Sounds" / filename,
        ):
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        print(
            f"{filename}: {len(samples) / SAMPLE_RATE:.2f}s "
            f"sha256={hashlib.sha256(data).hexdigest()}"
        )


if __name__ == "__main__":
    main()
