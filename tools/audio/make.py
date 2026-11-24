#!/usr/bin/env python3
"""Makes all of the game's music and special-move sounds from scratch (no samples, so there is
nothing to license). Needs numpy and ffmpeg. Run from the repository root:

    python3 tools/audio/make.py

Writes assets/audio/*.flac. Music loops without a seam: every note that rings past the end of the
loop wraps round to its start. sfx.flac is one sheet, one sound every SLOT seconds, in the order of
SFX below (the same order as src/shared/AudioIds.luau).
"""
import os, subprocess, sys, wave
import numpy as np

SR = 44100
SLOT = 3.0
OUT = "assets/audio"
rng = np.random.default_rng(7)


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def t_(sec):
    return np.arange(int(sec * SR)) / SR


def filt(x, cut, kind="low", order=2):
    """Butterworth filter (cut in Hz; a pair for a band), done in the frequency domain."""
    n = x.shape[-1]
    m = n + 4096
    f = np.fft.rfftfreq(m, 1 / SR)

    def low(c):
        u = 1j * f / c
        return 1 / (1 + 1.4142 * u + u * u)

    def high(c):
        u = 1j * f / c
        return u * u / (1 + 1.4142 * u + u * u)

    h = low(cut) if kind == "low" else high(cut) if kind == "high" else high(cut[0]) * low(cut[1])
    return np.fft.irfft(np.fft.rfft(x, m) * h, m)[..., :n]


def fftconvolve(a, b):
    m = len(a) + len(b) - 1
    return np.fft.irfft(np.fft.rfft(a, m) * np.fft.rfft(b, m), m)


def adsr(n, a, d, s, r):
    """Envelope n samples long; a/d/r in seconds, release inside the n samples."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    tail = np.clip((n / SR - t) / max(r, 1e-4), 0, 1)
    return e * tail


def saw(f, t, ph=0.0):
    """Band-limited enough: a sum of harmonics under 12 kHz."""
    out = np.zeros_like(t)
    for k in range(1, min(40, int(12000 / f)) + 1):
        out += np.sin(2 * np.pi * k * (f * t + ph)) / k * (1 if k % 2 else -1)
    return out * 0.6


def square(f, t, ph=0.0):
    out = np.zeros_like(t)
    for k in range(1, min(40, int(12000 / f)) + 1, 2):
        out += np.sin(2 * np.pi * k * (f * t + ph)) / k
    return out


def pluck(m, sec=1.6, bright=0.5):
    """Plucked string (Karplus-Strong): the koto."""
    f = hz(m)
    n = int(sec * SR)
    p = int(SR / f)
    buf = filt(rng.uniform(-1, 1, p), 2000 + 6000 * bright)
    out = np.zeros(n)
    for i in range(0, n, p):
        c = min(p, n - i)
        out[i : i + c] = buf[:c]
        buf = 0.994 * (0.5 * buf + 0.5 * np.roll(buf, 1))
    return out * adsr(n, 0.001, 9, 0, 0.1) / (np.abs(out).max() + 1e-6)


def kick(hard=1.0):
    t = t_(0.35)
    f = 46 + 130 * np.exp(-t * 38)
    return np.tanh(2 * hard * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)) * 0.9


def snare():
    t = t_(0.28)
    n = filt(rng.normal(0, 1, len(t)), [900, 9000], "band")
    return 0.45 * n * np.exp(-t * 18) + 0.4 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 24)


def clap():
    t = t_(0.3)
    n = filt(rng.normal(0, 1, len(t)), [1100, 5000], "band")
    e = sum(np.where(t > d, np.exp(-(t - d) * 60), 0) for d in (0, 0.012, 0.024)) * 0.5
    return 0.6 * n * (e + np.where(t > 0.03, 0.6 * np.exp(-(t - 0.03) * 16), 0))


def hat(open_=False):
    t = t_(0.25 if open_ else 0.07)
    return 0.22 * filt(rng.normal(0, 1, len(t)), 7500, "high") * np.exp(-t * (14 if open_ else 60))


def taiko():
    t = t_(0.7)
    f = 72 + 50 * np.exp(-t * 25)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6)
    return body * 0.9 + 0.2 * filt(rng.normal(0, 1, len(t)), 1200) * np.exp(-t * 45)


class Loop:
    def __init__(self, bpm, bars):
        self.beat = 60 / bpm
        self.bars = bars
        self.n = int(round(bars * 4 * self.beat * SR))
        self.bus = {}

    def add(self, bus, at_beats, x, gain=1.0, pan=0.0):
        """Mix x in at a beat, wrapping round the end of the loop. pan -1..1."""
        b = self.bus.setdefault(bus, np.zeros((self.n, 2)))
        i = int(round(at_beats * self.beat * SR)) % self.n
        st = np.stack([x * np.sqrt((1 - pan) / 2), x * np.sqrt((1 + pan) / 2)], 1) * gain * 1.414
        while len(st):
            c = min(len(st), self.n - i)
            b[i : i + c] += st[:c]
            st, i = st[c:], 0

    def circ(self, x, ir):
        """Circular convolution, so reverb tails wrap as well."""
        k = np.zeros((self.n, 2))
        m = min(len(ir), self.n)
        k[:m] = ir[:m]
        return np.fft.irfft(np.fft.rfft(x, axis=0) * np.fft.rfft(k, axis=0), self.n, axis=0)

    def reverb(self, bus, sec=1.8, wet=0.25):
        t = t_(sec)
        ir = rng.normal(0, 1, (len(t), 2)) * np.exp(-t * 4.5 / sec * 1.5)[:, None]
        ir = filt(ir.T, 5000).T
        ir /= np.sqrt((ir**2).sum(0))
        self.bus[bus] = self.bus[bus] + wet * self.circ(self.bus[bus], ir)

    def delay(self, bus, beats=0.75, fb=0.35, wet=0.35):
        x = self.bus[bus]
        d = int(beats * self.beat * SR)
        y, g = x.copy(), wet
        for k in range(1, 5):
            e = np.roll(x, d * k, axis=0)
            y += g * (e[:, ::-1] if k % 2 else e)
            g *= fb
        self.bus[bus] = y

    def duck(self, bus, depth=0.6, every=1.0):
        """Sidechain pump on every beat."""
        ph = (np.arange(self.n) / SR / self.beat % every) / every
        self.bus[bus] = self.bus[bus] * (1 - depth * np.exp(-ph * 5) * (ph < 1))[:, None]

    def mix(self, gains, loud=0.16):
        x = sum(self.bus[k] * g for k, g in gains.items())
        x = x - x.mean(0)
        # a little air on top (a shelf), wrapping like everything else
        f = np.fft.rfftfreq(self.n, 1 / SR)[:, None]
        x = np.fft.irfft(np.fft.rfft(x, axis=0) * (1 + 1.6 * f**2 / (f**2 + 2800.0**2)), self.n, axis=0)
        x *= loud / np.sqrt((x**2).mean())
        return np.tanh(x * 1.15) / 1.15 * 0.95


def chord_pad(notes, sec, cut):
    t = t_(sec)
    out = [np.zeros_like(t), np.zeros_like(t)]
    for m in notes:
        for det, ch in ((-0.06, 0), (0.06, 1), (0.0, 0), (0.02, 1)):
            out[ch] += saw(hz(m + det), t, rng.random())
    e = adsr(len(t), 0.15, 8, 0.8, 0.4)
    return [filt(o, cut) * e * 0.12 for o in out]


def bass_note(m, sec, cut=700, drive=1.5):
    t = t_(sec)
    x = saw(hz(m), t) + 0.6 * np.sin(2 * np.pi * hz(m) * t)
    return np.tanh(drive * filt(x, cut)) * adsr(len(t), 0.004, 0.25, 0.5, 0.03) * 0.5


def lead_note(m, sec, kind="square"):
    t = t_(sec)
    vib = 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 4 - 0.6, 0, 1)
    tt = t + np.cumsum(vib) / SR
    x = (square if kind == "square" else saw)(hz(m), tt) + 0.5 * saw(hz(m + 0.08), tt)
    return filt(x, 3800) * adsr(len(t), 0.008, 0.4, 0.55, 0.06) * 0.35


def arp_note(m, sec=0.28, cut=3000):
    t = t_(sec)
    x = saw(hz(m), t) + saw(hz(m + 0.1), t, 0.3)
    return filt(x, cut) * np.exp(-t * 11) * 0.3


def pads(L, prog, cut, bars_each=1):
    for bar in range(0, L.bars, bars_each):
        ch = prog[(bar // bars_each) % len(prog)]
        l, r = chord_pad(ch, 4 * L.beat * bars_each + 0.3, cut)
        L.add("pad", bar * 4, l, 1, -0.7)
        L.add("pad", bar * 4, r, 1, 0.7)


def melody(L, bus, start_bar, seq, kind="square", gain=1.0, up=0):
    """seq: list of (note or None, beats)."""
    b = start_bar * 4
    for m, d in seq:
        if m is not None:
            L.add(bus, b, lead_note(m + up, d * L.beat * 0.95 + 0.05, kind), gain)
        b += d


def menu():
    L = Loop(98, 24)
    prog = [[57, 60, 64, 67], [53, 57, 60, 64], [48, 55, 60, 64], [55, 59, 62, 69]]
    pads(L, prog, 1500)
    for bar in range(L.bars):
        ch = prog[bar % 4]
        for s in range(16):
            m = ch[[0, 2, 1, 3, 2, 1, 3, 2][s % 8]] + (12 if s % 8 < 5 else 24)
            L.add("arp", bar * 4 + s / 4, arp_note(m, 0.3, 1800 + 900 * np.sin(bar / 24 * 6.28) ** 2), 0.8, 0.5 * np.sin(s * 1.3))
        for s in (0, 1.5, 2.5, 3):
            L.add("bass", bar * 4 + s, bass_note(ch[0] - 24 if ch[0] > 50 else ch[0] - 12, 0.5 * L.beat + 0.1, 500), 1)
        if bar >= 4:
            for b in range(4):
                L.add("drum", bar * 4 + b, kick(0.8), 0.8 if b % 2 == 0 else 0)
                L.add("drum", bar * 4 + b + 0.5, hat(), 0.8, 0.2)
                if b % 2:
                    L.add("drum", bar * 4 + b, clap(), 0.5)
    tune = [(76, 1.5), (74, 0.5), (72, 1), (69, 1), (72, 2), (None, 1), (67, 1), (67, 1.5), (69, 0.5), (72, 1), (76, 1), (74, 3), (None, 1)]
    tune2 = tune[:7] + [(79, 1), (76, 1.5), (74, 0.5), (72, 1), (74, 1), (69, 3)]
    melody(L, "lead", 8, tune)
    melody(L, "lead", 12, tune2)
    melody(L, "lead", 20, tune)
    L.delay("arp"); L.delay("lead", 0.75, 0.4, 0.4)
    for b, w in (("pad", 0.5), ("arp", 0.25), ("lead", 0.4), ("drum", 0.08)):
        L.reverb(b, 2.2, w)
    L.duck("pad", 0.35, 2)
    return L.mix(dict(pad=0.9, arp=0.55, bass=0.75, drum=0.6, lead=0.5), 0.14)


def rooftop():
    L = Loop(126, 32)
    prog = [[52, 55, 59, 62], [48, 52, 55, 59], [55, 59, 62, 66], [50, 54, 57, 64]]
    pads(L, prog, 2200)
    for bar in range(L.bars):
        ch = prog[bar % 4]
        root = [40, 36, 43, 38][bar % 4]
        for s in range(16):
            if s % 4 != 0:
                L.add("bass", bar * 4 + s / 4, bass_note(root + (12 if s % 8 == 6 else 0), 0.25 * L.beat, 600 + 500 * (bar % 8 > 3), 2), 1)
        if bar % 16 >= 4:
            for s in range(16):
                if s % 3 != 2:
                    L.add("arp", bar * 4 + s / 4, arp_note(ch[s % 4] + 24, 0.22, 2400), 0.7, 0.6 * (-1) ** s)
        for b in range(4):
            L.add("drum", bar * 4 + b, kick(1.2), 1)
            L.add("drum", bar * 4 + b + 0.5, hat(True), 0.7, 0.15)
            L.add("drum", bar * 4 + b + 0.25, hat(), 0.5, -0.2); L.add("drum", bar * 4 + b + 0.75, hat(), 0.5, -0.2)
            if b % 2:
                L.add("drum", bar * 4 + b, clap(), 0.8)
        if bar % 8 == 7:
            for s in range(8):
                L.add("drum", bar * 4 + 2 + s / 4, snare(), 0.3 + 0.07 * s)
    a = [(71, 0.75), (71, 0.75), (74, 0.5), (76, 1), (74, 1), (72, 0.75), (71, 0.75), (67, 0.5), (64, 2),
         (67, 0.75), (69, 0.75), (71, 0.5), (74, 1), (71, 1), (69, 0.75), (66, 0.75), (69, 0.5), (64, 2)]
    b = [(76, 0.75), (76, 0.75), (79, 0.5), (78, 1), (74, 1), (76, 0.75), (74, 0.75), (72, 0.5), (71, 2),
         (74, 0.75), (74, 0.75), (71, 0.5), (74, 1), (79, 1), (78, 1.5), (74, 0.5), (76, 2)]
    for s, q in ((8, a), (12, b), (20, a), (24, b), (28, b)):
        melody(L, "lead", s, q)
    L.delay("arp", 0.75, 0.4, 0.4); L.delay("lead", 0.75, 0.35, 0.3)
    for k, w in (("pad", 0.3), ("arp", 0.2), ("lead", 0.3), ("drum", 0.06)):
        L.reverb(k, 1.6, w)
    L.duck("pad", 0.75); L.duck("bass", 0.35); L.duck("arp", 0.4)
    return L.mix(dict(pad=0.8, arp=0.5, bass=0.7, drum=0.75, lead=0.5))


def sakura():
    L = Loop(112, 24)
    # in-scale on D: D Eb G A Bb
    prog = [[50, 57, 62, 67], [46, 53, 62, 65], [43, 55, 58, 62], [45, 57, 62, 64]]
    pads(L, prog, 1400)
    for bar in range(L.bars):
        ch = prog[bar % 4]
        for s in (0, 1.5, 2, 3.5):
            L.add("bass", bar * 4 + s, bass_note([38, 34, 43, 45][bar % 4], 0.45 * L.beat, 450), 1)
        L.add("drum", bar * 4, taiko(), 0.9); L.add("drum", bar * 4 + 2.5, taiko(), 0.6)
        if bar >= 4:
            for b in range(4):
                L.add("drum", bar * 4 + b, kick(0.8), 0.7)
                L.add("drum", bar * 4 + b + 0.5, hat(), 0.8, 0.2)
                if b % 2:
                    L.add("drum", bar * 4 + b, clap(), 0.45)
        for s in range(8):
            m = [62, 67, 69, 74, 70, 69, 67, 63 if bar % 4 == 1 else 62][s]
            L.add("koto2", bar * 4 + s / 2, pluck(m, 0.9, 0.3), 0.4, 0.5 * (-1) ** s)
    q = [(74, 1), (75, 0.5), (74, 0.5), (70, 1), (69, 1), (67, 1.5), (69, 0.5), (70, 2),
         (74, 1), (79, 1), (81, 0.5), (79, 0.5), (75, 1), (74, 3), (None, 1)]
    q2 = [(81, 0.5), (82, 0.5), (81, 1), (79, 1), (75, 1), (74, 1.5), (70, 0.5), (74, 2),
          (69, 0.5), (70, 0.5), (74, 1), (75, 0.5), (74, 0.5), (70, 1), (69, 3), (None, 1)]
    for st, seq in ((4, q), (8, q2), (12, q), (16, q2), (20, q)):
        b = st * 4
        for m, d in seq:
            if m:
                L.add("koto", b, pluck(m, 2.0, 0.8), 1, -0.15)
                if d >= 2:
                    for k in range(1, 4):
                        L.add("koto", b + 0.5 * k, pluck(m, 0.8, 0.6), 0.45, -0.15)
                if st >= 12:
                    L.add("lead", b, lead_note(m - 12, d * L.beat, "saw"), 0.5)
            b += d
    L.delay("koto", 0.75, 0.35, 0.3); L.delay("koto2", 0.5, 0.3, 0.25)
    for k, w in (("pad", 0.5), ("koto", 0.35), ("koto2", 0.3), ("drum", 0.15), ("lead", 0.4)):
        L.reverb(k, 2.2, w)
    L.duck("pad", 0.4)
    return L.mix(dict(pad=0.7, koto=0.7, koto2=0.45, bass=0.65, drum=0.7, lead=0.35), 0.15)


def ranked():
    L = Loop(140, 32)
    prog = [[50, 53, 57, 60], [46, 50, 53, 57], [48, 52, 55, 60], [45, 48, 52, 57]]
    pads(L, prog, 2000)
    for bar in range(L.bars):
        ch = prog[bar % 4]
        root = [38, 34, 36, 33][bar % 4]
        for s in range(16):
            if s in (0, 3, 6, 7, 8, 11, 14, 15):
                L.add("bass", bar * 4 + s / 4, bass_note(root + (12 if s in (7, 15) else 0), 0.24 * L.beat, 1000, 3), 1)
            L.add("arp", bar * 4 + s / 4, arp_note(ch[[0, 1, 2, 3, 2, 1, 3, 2][s % 8]] + 24, 0.18, 1600 + 160 * (bar % 16)), 0.7, 0.5 * (-1) ** s)
        half = bar % 16 < 2
        for s in ((0, 2.5) if half else (0, 0.75, 1.75, 2.5)):
            L.add("drum", bar * 4 + s, kick(1.6), 1)
        for s in (1, 3):
            L.add("drum", bar * 4 + s, snare(), 1.1); L.add("drum", bar * 4 + s, clap(), 0.5)
        if not half:
            L.add("drum", bar * 4 + 3.75, snare(), 0.35)
            for s in range(8):
                L.add("drum", bar * 4 + s / 2, hat(s == 7), 0.9, 0.2)
        if bar % 8 == 7:
            for s in range(6):
                L.add("drum", bar * 4 + 2.5 + s / 4, snare(), 0.35 + 0.1 * s)
    a = [(69, 0.5), (69, 0.5), (72, 0.5), (74, 1.5), (77, 1), (76, 0.5), (74, 0.5), (72, 0.5), (74, 1.5), (70, 1),
         (72, 0.5), (72, 0.5), (76, 0.5), (79, 1.5), (77, 1), (76, 1.5), (72, 1.5), (69, 1)]
    b = [(81, 1.5), (77, 1.5), (74, 1), (82, 1.5), (81, 1.5), (77, 1), (79, 1.5), (76, 1.5), (72, 1), (76, 1), (77, 1), (79, 1), (76, 1)]
    for s, q in ((4, a), (8, a), (12, b), (20, a), (24, b), (28, b)):
        melody(L, "lead", s, q, "saw")
    L.delay("lead", 0.75, 0.35, 0.3); L.delay("arp", 0.75, 0.3, 0.25)
    for k, w in (("pad", 0.3), ("lead", 0.3), ("drum", 0.07), ("arp", 0.15)):
        L.reverb(k, 1.5, w)
    L.duck("pad", 0.6); L.duck("bass", 0.2)
    return L.mix(dict(pad=0.7, arp=0.42, bass=0.65, drum=0.8, lead=0.52), 0.17)


def final():
    L = Loop(152, 24)
    prog = [[48, 51, 55, 60], [48, 51, 56, 60], [46, 50, 53, 58], [47, 50, 55, 59]]
    pads(L, prog, 2600)
    for bar in range(L.bars):
        ch = prog[bar % 4]
        root = [36, 32, 34, 31][bar % 4]
        for s in range(16):
            L.add("bass", bar * 4 + s / 4, bass_note(root + (12 if s % 4 == 2 else 0), 0.2 * L.beat, 1100, 3), 1)
            m = [72, 75, 79, 75, 80, 79, 75, 74][s % 8]
            m += {2: -2, 3: -1}.get(bar % 4, 0)
            L.add("arp", bar * 4 + s / 4, arp_note(m, 0.17, 3400), 0.8, 0.5 * (-1) ** s)
        for b in range(4):
            L.add("drum", bar * 4 + b, kick(1.6), 1)
            L.add("drum", bar * 4 + b + 0.5, hat(True), 0.8, 0.2)
            if b % 2:
                L.add("drum", bar * 4 + b, snare(), 1.1)
        for s in (0, 0.75, 1.5):
            L.add("drum", bar * 4 + s, taiko(), 0.5)
        for c in (0, 1.5, 3):
            for m in ch:
                L.add("stab", bar * 4 + c, filt(saw(hz(m + 12), t_(0.3)), 3500) * np.exp(-t_(0.3) * 10), 0.14)
        if bar % 8 == 7:
            for s in range(8):
                L.add("drum", bar * 4 + 2 + s / 4, snare(), 0.3 + 0.09 * s)
    a = [(79, 1.5), (80, 0.5), (79, 1), (75, 1), (72, 1.5), (75, 0.5), (80, 2), (77, 1.5), (79, 0.5), (77, 1), (74, 1), (79, 2), (74, 1), (71, 1)]
    for s in (8, 12, 16, 20):
        melody(L, "lead", s, a, "saw")
    L.delay("lead", 0.75, 0.3, 0.3)
    for k, w in (("pad", 0.3), ("lead", 0.3), ("drum", 0.07), ("stab", 0.3)):
        L.reverb(k, 1.4, w)
    L.duck("pad", 0.6); L.duck("bass", 0.25)
    return L.mix(dict(pad=0.6, arp=0.4, bass=0.6, drum=0.8, lead=0.5, stab=0.7), 0.17)


# ---- special moves -------------------------------------------------------------------------
def noise(sec):
    return rng.normal(0, 1, int(sec * SR))


def sweep(sec, f0, f1, curve=1.0, wave="sin"):
    t = t_(sec)
    f = f0 * (f1 / f0) ** ((t / sec) ** curve)
    ph = np.cumsum(f) / SR
    if wave == "saw":
        return filt(2 * (ph % 1) - 1, 9000)
    return np.sin(2 * np.pi * ph)


def nsweep(sec, f0, f1):
    """Noise through a moving band (a whoosh)."""
    n = noise(sec)
    out = np.zeros_like(n)
    win = 2048
    h = np.hanning(win)
    for i in range(0, len(n) - win, win // 2):
        k = i / len(n)
        f = f0 * (f1 / f0) ** k
        spec = np.fft.rfft(n[i : i + win] * h)
        fr = np.fft.rfftfreq(win, 1 / SR)
        out[i : i + win] += np.fft.irfft(spec * np.exp(-((np.log2((fr + 1) / f)) ** 2) * 2.5))
    return out / (np.abs(out).max() + 1e-6)


def env(x, a, d):
    t = np.arange(len(x)) / SR
    return x * np.minimum(t / a, 1) * np.exp(-np.maximum(t - a, 0) / d) * np.clip((len(x) / SR - t) / 0.03, 0, 1)


def put(*items):
    """items: (start seconds, signal, gain)."""
    n = max(int(s * SR) + len(x) for s, x, _ in items)
    out = np.zeros(n)
    for s, x, g in items:
        i = int(s * SR)
        out[i : i + len(x)] += x * g
    return out


def boom(sec=1.0, f=55, drive=2):
    t = t_(sec)
    return np.tanh(drive * np.sin(2 * np.pi * np.cumsum(f + 120 * np.exp(-t * 22)) / SR)) * np.exp(-t * 4.5)


def bell(m, sec=1.2, d=0.4):
    t = t_(sec)
    f = hz(m)
    return sum(np.sin(2 * np.pi * f * r * t) * a * np.exp(-t / d * r**0.6) for r, a in ((1, 1), (2.76, 0.4), (5.4, 0.2))) * 0.5


def crackle(sec, density):
    x = np.where(rng.random(int(sec * SR)) < density / SR, rng.normal(0, 4, int(sec * SR)), 0)
    return np.clip(fftconvolve(x, filt(noise(0.012) * np.exp(-t_(0.012) * 300), 1500, "high"))[: len(x)], -1, 1)


def s_curve():
    x = sweep(0.7, 500, 1500, 1.2) * (1 + 0.6 * np.sin(2 * np.pi * 18 * t_(0.7)))
    return put((0, env(nsweep(0.8, 600, 5000), 0.15, 0.25), 0.8), (0, env(x, 0.05, 0.3), 0.35))


def s_smash():
    return put((0, env(noise(0.06), 0.001, 0.02), 0.6), (0, boom(1.2, 48, 3), 0.9), (0, env(filt(noise(1.1), 2500), 0.002, 0.25), 0.5),
               (0, env(crackle(0.9, 900), 0.001, 0.35), 0.7), (0, env(sweep(0.35, 3500, 120, 0.5, "saw"), 0.001, 0.12), 0.5))


def s_phantom():
    x = [(0.11 * k, env(nsweep(0.6, 2500, 700), 0.1, 0.2), 0.5 - 0.1 * k) for k in range(3)]
    v = [(0.11 * k, env(sweep(0.8, 620 + 40 * k, 480 + 60 * k) * (1 + 0.5 * np.sin(2 * np.pi * 7 * t_(0.8))), 0.08, 0.3), 0.35) for k in range(3)]
    return put(*x, *v)


def s_blind():
    return put((0, env(nsweep(0.9, 4000, 150), 0.02, 0.5), 0.8), (0, env(sweep(0.9, 300, 55), 0.02, 0.4), 0.6), (0.1, env(bell(50, 0.9, 0.5), 0.01, 0.5), 0.3))


def s_slow():
    tick = [(0.1 * sum(1.35**j for j in range(k)), env(bell(88 - 2 * k, 0.15, 0.05), 0.001, 0.05), 0.5) for k in range(5)]
    return put((0, env(sweep(1.5, 900, 70, 0.7), 0.03, 0.7), 0.55), (0, env(nsweep(1.4, 3000, 200), 0.05, 0.6), 0.35), *tick)


def s_barrier():
    ch = [(0.05 * k, env(bell(m, 1.4, 0.5), 0.005, 0.6), 0.4) for k, m in enumerate((60, 67, 72, 79))]
    hum = filt(saw(110, t_(1.3)) + saw(110.7, t_(1.3)), 900)
    return put((0, env(sweep(0.4, 150, 900), 0.05, 0.2), 0.4), (0.1, env(hum, 0.15, 0.5), 0.35), *ch)


def s_gravity():
    w = sweep(1.5, 110, 32) * (1 + 0.7 * np.sin(2 * np.pi * np.cumsum(np.linspace(4, 14, int(1.5 * SR))) / SR))
    return put((0, env(w, 0.15, 0.8), 0.9), (0, env(nsweep(1.5, 2200, 90), 0.4, 0.6), 0.6))


def s_blink():
    return put((0, env(sweep(0.18, 400, 4200, 1.4), 0.01, 0.2), 0.6), (0.16, env(noise(0.05), 0.001, 0.02), 0.5),
               (0.17, env(bell(96, 0.6, 0.15), 0.001, 0.2), 0.5), (0.17, boom(0.35, 80, 1), 0.4))


def s_zigzag():
    z = [(0.09 * k, env(sweep(0.11, (700, 2400)[k % 2], (2400, 700)[k % 2], 1, "saw"), 0.004, 0.08), 0.5) for k in range(7)]
    return put(*z, (0, env(crackle(0.8, 1200), 0.01, 0.4), 0.4))


def s_quantum():
    x = env(sweep(0.35, 250, 2600, 2), 0.2, 0.2)
    ice = [(0.36 + 0.03 * k, env(bell(m, 1.1, 0.3), 0.001, 0.35), 0.35) for k, m in enumerate((84, 91, 86, 95))]
    return put((0, x, 0.5), (0.35, env(noise(0.04), 0.001, 0.015), 0.6), (0.35, boom(0.5, 60, 1.5), 0.5), *ice)


def s_meteor():
    return put((0, env(sweep(0.85, 2400, 260, 1.1), 0.1, 1.0), 0.3), (0, env(nsweep(0.9, 5000, 500), 0.3, 0.8), 0.5),
               (0.8, boom(1.3, 40, 3), 1.0), (0.8, env(filt(noise(1.2), 1600), 0.002, 0.35), 0.7), (0.8, env(crackle(1.0, 400), 0.01, 0.4), 0.4))


def s_emp():
    buzz = np.sign(np.sin(2 * np.pi * 90 * t_(0.9))) * (rng.random(int(0.9 * SR) // 900 + 1).repeat(900)[: int(0.9 * SR)] > 0.35)
    return put((0, env(sweep(0.3, 5000, 80, 0.6), 0.002, 0.2), 0.7), (0, boom(0.8, 50, 2), 0.7), (0.15, env(filt(buzz, [300, 5000], "band"), 0.01, 0.4), 0.35),
               (0.1, env(crackle(1.1, 1500), 0.01, 0.4), 0.5))


def s_barrierhit():
    return put((0, env(noise(0.05), 0.001, 0.02), 0.5), (0, boom(0.5, 90, 2), 0.6), *[(0, env(bell(m, 1.0, 0.3), 0.001, 0.35), 0.35) for m in (72, 79, 84)])


def jingle(seq, kind):
    it = []
    for at, notes, sec in seq:
        for m in notes:
            it.append((at, lead_note(m, sec, kind), 0.55))
            it.append((at, bell(m + 12, sec, 0.4), 0.2))
    return it


def s_win():
    return put(*jingle([(0, (67,), 0.14), (0.14, (72,), 0.14), (0.28, (76,), 0.14), (0.42, (79, 76, 72), 0.4), (0.84, (77, 81), 0.2), (1.06, (84, 79, 76, 72), 1.5)], "saw"),
               (0.42, boom(0.5, 55), 0.5), (1.06, boom(0.9, 50), 0.7), (1.06, env(filt(noise(1.3), 5000, "high"), 0.002, 0.4), 0.3))


def s_lose():
    return put(*jingle([(0, (67, 63), 0.35), (0.4, (65, 62), 0.35), (0.8, (63, 60), 0.35), (1.2, (55, 59, 62), 1.3)], "square"), (1.2, boom(0.9, 45, 1), 0.5))


SFX = [("Curve", s_curve), ("Smash", s_smash), ("Phantom", s_phantom), ("Blind", s_blind), ("TimeSlow", s_slow), ("Barrier", s_barrier),
       ("GravityWell", s_gravity), ("Blink", s_blink), ("Zigzag", s_zigzag), ("QuantumStop", s_quantum), ("Meteor", s_meteor), ("EMP", s_emp),
       ("BarrierHit", s_barrierhit), ("Win", s_win), ("Lose", s_lose)]


def roomy(x):
    """A short stereo room so the sounds are not dry. Always exactly SLOT - 0.1 s long."""
    n = int((SLOT - 0.1) * SR)
    x = np.pad(x, (0, max(0, n - len(x))))[:n]
    t = t_(0.9)
    out = np.stack([x, x], 1)
    for c in (0, 1):
        ir = filt(rng.normal(0, 1, len(t)) * np.exp(-t * 7), 6000)
        ir /= np.sqrt((ir**2).sum())
        out[:, c] += 0.22 * fftconvolve(x, ir)[:n]
    out = out / np.abs(out).max()
    out = np.tanh(out * 1.6)
    # even loudness over the loudest 0.4 s
    p = np.convolve((out**2).mean(1), np.ones(int(0.4 * SR)) / int(0.4 * SR), "same").max()
    out *= min(0.24 / np.sqrt(p), 0.92 / np.abs(out).max())
    out[-int(0.2 * SR) :] *= np.linspace(1, 0, int(0.2 * SR))[:, None]
    return out


def save(name, x):
    w = f"{OUT}/{name}.wav"
    with wave.open(w, "wb") as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, f"{OUT}/{name}.flac"], check=True)
    os.remove(w)
    print(f"{name}: {len(x) / SR:.2f}s peak {np.abs(x).max():.2f} rms {np.sqrt((x**2).mean()):.3f} seam {np.abs(x[0] - x[-1]).max():.3f}")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    want = sys.argv[1:]
    for name, fn in (("menu", menu), ("rooftop", rooftop), ("sakura", sakura), ("ranked", ranked), ("final", final)):
        if not want or name in want:
            save(name, fn())
    if not want or "sfx" in want:
        sheet = np.zeros((int(len(SFX) * SLOT * SR), 2))
        for i, (n, fn) in enumerate(SFX):
            x = roomy(fn())
            a = int(i * SLOT * SR)
            sheet[a : a + len(x)] = x
            print("  ", n, f"peak {np.abs(x).max():.2f}")
        save("sfx", sheet)
