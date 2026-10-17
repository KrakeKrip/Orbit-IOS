"""Original Orbit notification and completion tones: mono 44.1kHz 16-bit PCM, <2 seconds.
Regenerate from repository root. No downloaded or platform audio assets.
"""
import math
from pathlib import Path
import struct
import wave

RATE = 44100
TONES = {
    'complete': [(0.0, 660, .09, .36), (.055, 990, .23, .32), (.055, 1320, .19, .10)],
    'chime': [(0.0, 880, .85, .34), (.18, 1320, .95, .23)],
    'drop': [(0.0, 660, .45, .40), (.13, 990, .65, .24)],
    'signal': [(0.0, 740, .24, .34), (.32, 740, .24, .34), (.64, 988, .42, .30)],
}
root = Path(__file__).resolve().parents[1] / 'apple/OrbitIOS/OrbitIOS'
for name, notes in TONES.items():
    length = max(start + duration for start, _, duration, _ in notes) + .08
    samples = []
    for i in range(math.ceil(length * RATE)):
        t = i / RATE
        value = 0.0
        for start, hz, duration, amplitude in notes:
            age = t - start
            if 0 <= age < duration:
                if name == 'complete':
                    # A crisp wooden attack followed by a brighter rising
                    # consonant pair; fuller and shorter than the first tone.
                    envelope = min(1.0, age / .0025) * math.exp(-3.2 * age / duration)
                    envelope *= min(1.0, (duration - age) / .02)
                    partials = (math.sin(2 * math.pi * hz * age)
                                + .28 * math.sin(4 * math.pi * hz * age)
                                + .08 * math.sin(6 * math.pi * hz * age))
                else:
                    envelope = min(1.0, age / .008) * math.exp(-5 * age / duration)
                    envelope *= min(1.0, (duration - age) / .03)
                    partials = math.sin(2 * math.pi * hz * age) + .12 * math.sin(4 * math.pi * hz * age)
                value += amplitude * envelope * partials
        if name == 'complete' and t < .025:
            # Smooth, deterministic transient (not a discontinuous click).
            value += .10 * min(1.0, t / .0005) * math.exp(-t / .0035) * math.sin(2 * math.pi * 2400 * t)
        assert abs(value) < 1.0
        samples.append(round(value * 32767))
    if name == 'complete':
        gain = .55 * 32767 / max(abs(x) for x in samples)
        samples = [round(x * gain) for x in samples]
    with wave.open(str(root / f'orbit-{name}.wav'), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(struct.pack(f'<{len(samples)}h', *samples))
    print(f'{name}: {len(samples)/RATE:.2f}s, peak {max(abs(x) for x in samples)/32767:.3f}')
