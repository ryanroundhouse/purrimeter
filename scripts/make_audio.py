"""Original deterministic chiptune score and effects; no external samples/dependencies."""
import math, wave, struct, random
from pathlib import Path
RATE = 22050
OUT = Path(__file__).resolve().parent.parent / 'Assets'
rng = random.Random(42)
def hz(note): return 440 * 2 ** ((note - 69) / 12)
def write(name, samples):
    peak = max(1, max(abs(x) for x in samples) / .85)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x / peak)) * 32767)) for x in samples))
def note(buf, start, duration, midi, gain=.1, voice='pulse'):
    offset = int(start * RATE); length = int(duration * RATE); freq = hz(midi)
    for i in range(length):
        k = offset + i
        if k >= len(buf): break
        t = i / RATE; phase = (t * freq) % 1
        if voice == 'triangle': value = 1 - 4 * abs(phase - .5)
        elif voice == 'sine': value = math.sin(2 * math.pi * phase)
        else: value = 1 if phase < .25 else -1
        env = min(1, t / .006) * min(1, (duration-t) / .04) * (.7 + .3 * math.exp(-t*9))
        buf[k] += value * gain * env
# 32 bars at 120 BPM: A minor / F / C / G, with an answering melody.
beat = .5; bars = 32; duration = bars * 4 * beat
buf = [0.] * int(duration * RATE)
chords = [(45, [69,72,76,79]), (41,[65,69,72,76]), (48,[67,72,76,79]), (43,[67,71,74,79])]
melodies = [[76,0,79,81,79,76,72,74], [76,77,76,72,69,0,72,74], [79,0,76,79,84,83,79,76], [74,76,79,0,74,71,72,74]]
for bar in range(bars):
    root, chord = chords[bar % 4]; start=bar*4*beat
    for b in range(4):
        note(buf,start+b*beat,.38,root+(12 if b%2 else 0),.16,'triangle')
    for step in range(8):
        note(buf,start+step*beat/2,.16,chord[step%4],.038,'pulse')
        melody=melodies[(bar//2)%4][step]
        if melody: note(buf,start+step*beat/2,.21,melody+(12 if bar>=16 and bar<24 else 0),.075,'pulse')
    for step in range(8):
        offset=int((start+step*beat/2)*RATE)
        for i in range(int(.07*RATE)):
            if offset+i >= len(buf): break
            buf[offset+i] += rng.uniform(-1,1)*.025*math.exp(-i/RATE*65)
    for b in range(4):
        offset=int((start+b*beat)*RATE)
        for i in range(int(.15*RATE)):
            if offset+i>=len(buf): break
            t=i/RATE
            if b%2==0: v=math.sin(2*math.pi*(58*t+7*(1-math.exp(-t*35))))*.20*math.exp(-t*24)
            else: v=rng.uniform(-1,1)*.09*math.exp(-t*28)
            buf[offset+i]+=v
write('garden',buf)
for name, notes in {'build':[60,64,67], 'upgrade':[60,64,67,72,76], 'coin':[88,95], 'wave':[60,67,72], 'clear':[72,76,79,84], 'escape':[64,52], 'win':[72,76,79,84,79,84,88], 'lose':[64,60,55,48]}.items():
    length=len(notes)*.09+.13; buf=[0.]*int(length*RATE)
    for j,n in enumerate(notes): note(buf,j*.09,.16,n,.22,'triangle')
    write(name,buf)
for name, duration, freq, decay in [('bolt',.09,1300,35),('cannon',.24,100,15),('frost',.22,1900,12),('break',.35,70,10)]:
    buf=[]
    for i in range(int(duration*RATE)):
        t=i/RATE
        signal=math.sin(2*math.pi*(freq*t-freq*.6*t*t/duration))
        noise=rng.uniform(-1,1)
        v=(signal*(.7 if name in ('bolt','frost') else .3)+noise*(.2 if name in ('bolt','frost') else .7))*.4*math.exp(-t*decay)*min(1,t/.002)
        buf.append(v)
    write(name,buf)
print('Generated 64-second original loop and 12 sound effects.')
