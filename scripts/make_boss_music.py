"""Generate five original, deterministic boss scores using only synthesized voices.

Run from any directory with Python 3. Outputs go directly to game/assets.
Each 32-bar loop has its own key, tempo, harmony, melody and drum pattern.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "game" / "assets"
# Melody values are scale degrees in natural minor; None is a rest.
THEMES = [
    dict(name="Midnight March", bpm=144, tonic=57, roots=[0, 5, 2, 6],
         a=[0, None, 2, 4, 7, 4, 3, 2, 0, 2, 4, None, 6, 4, 2, 1],
         b=[7, 6, 4, 2, 5, None, 4, 3, 2, 4, 6, 7, 6, 4, 1, None]),
    dict(name="Bramble Chase", bpm=156, tonic=62, roots=[0, 3, 6, 0],
         a=[4, 4, None, 2, 3, 4, 7, None, 6, 4, 3, 2, 1, None, 0, 2],
         b=[7, None, 9, 8, 7, 6, 4, None, 5, 7, 6, 4, 3, 2, 1, 0]),
    dict(name="Moonlit Mischief", bpm=162, tonic=59, roots=[0, 6, 5, 4],
         a=[0, 4, 2, None, 0, 4, 6, 4, 3, None, 2, 6, 4, 2, 1, None],
         b=[4, 7, None, 6, 4, 9, 7, 6, 5, 4, 2, None, 3, 2, 1, 4]),
    dict(name="Thornwall Stomp", bpm=150, tonic=60, roots=[0, 2, 3, 5],
         a=[0, None, None, 0, 4, None, 3, 2, 5, None, 4, None, 2, 1, 0, None],
         b=[7, None, 4, 7, 9, None, 8, 7, 5, 4, None, 2, 3, 4, 1, None]),
    dict(name="Garden Guardians", bpm=168, tonic=55, roots=[0, 5, 3, 6],
         a=[7, 6, 4, 7, 9, None, 7, 4, 5, 4, 2, 5, 6, 4, 2, None],
         b=[9, 7, 6, 4, 7, 9, 11, None, 10, 9, 7, 6, 5, 4, 1, 2]),
]
SCALE = [0, 2, 3, 5, 7, 8, 10]


def pitch(tonic, degree):
    octave, step = divmod(degree, 7)
    return tonic + octave * 12 + SCALE[step]


def tone(buf, start, duration, midi, gain, voice="pulse", duty=.25):
    offset = round(start * RATE)
    count = round(duration * RATE)
    frequency = 440 * 2 ** ((midi - 69) / 12)
    for i in range(count):
        t = i / RATE
        phase = (t * frequency) % 1
        if voice == "triangle":
            sample = 1 - 4 * abs(phase - .5)
        else:
            # Zero-mean pulse; a short attack/release keeps notes from clicking.
            sample = (1 if phase < duty else 0) - duty
        envelope = min(1, t / .005, (duration - t) / .025)
        envelope *= .65 + .35 * math.exp(-t * 12)
        buf[(offset + i) % len(buf)] += sample * gain * envelope


def drum(buf, start, kind, gain, rng):
    duration = {"kick": .18, "snare": .13, "hat": .045, "crash": .3}[kind]
    offset = round(start * RATE)
    previous = 0.
    for i in range(round(duration * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        if kind == "kick":
            sample = math.sin(2 * math.pi * (48 * t + 2.8 * (1 - math.exp(-t * 40))))
            sample *= math.exp(-t * 25)
        elif kind == "snare":
            sample = (.75 * noise + .25 * math.sin(2 * math.pi * 185 * t)) * math.exp(-t * 32)
        else:
            sample = (noise - previous) * .5 * math.exp(-t * (80 if kind == "hat" else 14))
        previous = noise
        buf[(offset + i) % len(buf)] += sample * gain * min(1, t / .002)


def render(index, theme, target_rms):
    rng = random.Random(7400 + index)
    beat = 60 / theme["bpm"]
    buf = [0.] * round(32 * 4 * beat * RATE)
    tonic = theme["tonic"]
    for bar in range(32):
        start = bar * 4 * beat
        root = theme["roots"][bar % 4]
        melody = theme["b"] if (bar // 8) % 2 else theme["a"]
        # Half-bar bass figures and sixteenth-note arpeggios keep the pulse urgent.
        for step in range(8):
            degree = root + ([0, 0, 4, 7][step % 4] if index != 3 else [0, 0, 0, 4][step % 4])
            tone(buf, start + step * beat / 2, beat * .43, pitch(tonic - 24, degree), .34, "triangle")
        for step in range(16):
            chord_step = [0, 2, 4, 7][(step + index) % 4]
            tone(buf, start + step * beat / 4, beat * .19,
                 pitch(tonic, root + chord_step), .075, duty=.125)
        for step in range(8):
            degree = melody[(bar % 2) * 8 + step]
            if degree is None:
                continue
            # The second half adds octave answers and a quieter harmony.
            octave = 12 if bar >= 16 and step in (3, 7) else 0
            tone(buf, start + step * beat / 2, beat * .41,
                 pitch(tonic, degree) + octave, .25, duty=.25 if index % 2 == 0 else .5)
            if bar >= 24:
                tone(buf, start + step * beat / 2, beat * .36,
                     pitch(tonic, degree - 2), .075, "triangle")
        kicks = [[0, 2, 2.75], [0, 1.5, 2, 3.5], [0, .75, 2, 2.75], [0, .5, 2], [0, 1.5, 2, 2.5]][index]
        for b in kicks:
            drum(buf, start + b * beat, "kick", .40, rng)
        for b in (1, 3):
            drum(buf, start + b * beat, "snare", .19, rng)
        for step in range(8):
            drum(buf, start + step * beat / 2, "hat", .055 if step % 2 else .035, rng)
        if bar % 8 == 0:
            drum(buf, start, "crash", .10, rng)
        if bar % 8 == 7:
            for step in range(4):
                drum(buf, start + (3 + step / 4) * beat, "snare", .07 + step * .025, rng)
    # Gentle circular low-pass tames pulse-wave edges without breaking the loop.
    previous = buf[-1]
    for i, sample in enumerate(buf):
        buf[i] = .72 * sample + .28 * previous
        previous = sample
    peak = max(abs(sample) for sample in buf)
    rms = math.sqrt(sum(sample * sample for sample in buf) / len(buf))
    gain = min(.85 / peak, target_rms / rms)
    path = OUT / f"boss_music_{index + 1}.wav"
    pcm = bytearray()
    for sample in buf:
        pcm.extend(struct.pack("<h", round(sample * gain * 32767)))
    with wave.open(str(path), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(pcm)
    print(f"{path.name}: {theme['name']}, {theme['bpm']} BPM, {len(buf) / RATE:.2f}s, RMS {rms * gain:.3f}")


def main():
    with wave.open(str(OUT / "garden.wav"), "rb") as source:
        pcm = source.readframes(source.getnframes())
    samples = [value[0] / 32768 for value in struct.iter_unpack("<h", pcm)]
    target_rms = math.sqrt(sum(value * value for value in samples) / len(samples))
    for index, theme in enumerate(THEMES):
        render(index, theme, target_rms)


if __name__ == "__main__":
    main()
