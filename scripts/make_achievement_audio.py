"""Generate the original garden achievement chime (no external samples)."""
import math
import struct
import wave
from pathlib import Path

rate = 22050
samples = [0.0] * int(rate * 0.95)
for start, midi, duration in [(0, 72, .18), (.12, 76, .18), (.24, 79, .18), (.38, 84, .48)]:
    frequency = 440 * 2 ** ((midi - 69) / 12)
    for i in range(int(duration * rate)):
        t = i / rate
        envelope = min(1, t / .008) * min(1, (duration - t) / .1)
        phase = (t * frequency) % 1
        samples[int(start * rate) + i] += (1 - 4 * abs(phase - .5)) * envelope * .35
with wave.open(str(Path(__file__).resolve().parents[1] / 'game/assets/achievement.wav'), 'wb') as output:
    output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    output.writeframes(b''.join(struct.pack('<h', int(s * 32767)) for s in samples))
