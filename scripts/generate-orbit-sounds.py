"""Original Orbit notification tones: mono 44.1kHz 16-bit PCM, <2 seconds.
Regenerate from repository root. No downloaded or platform audio assets.
"""
import math
from pathlib import Path
import struct
import wave

RATE = 44100
TONES = {
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
                envelope = min(1.0, age / .008) * math.exp(-5 * age / duration)
                envelope *= min(1.0, (duration - age) / .03)
                value += amplitude * envelope * (math.sin(2 * math.pi * hz * age) + .12 * math.sin(4 * math.pi * hz * age))
        assert abs(value) < 1.0
        samples.append(round(value * 32767))
    with wave.open(str(root / f'orbit-{name}.wav'), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(struct.pack(f'<{len(samples)}h', *samples))
    print(f'{name}: {len(samples)/RATE:.2f}s, peak {max(abs(x) for x in samples)/32767:.3f}')
