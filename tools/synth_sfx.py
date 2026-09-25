#!/usr/bin/env python3
"""Synthesizes placeholder combat SFX into audio/sfx/*.wav.

Placeholder-quality procedural sounds so combat has audio feedback before a
real sound pass. Re-run to regenerate: python3 tools/synth_sfx.py
"""
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")
rng = np.random.default_rng(7)


def env(n, attack=0.005, decay=0.2, curve=4.0):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    d = np.exp(-curve * np.maximum(t - attack, 0) / decay)
    return a * d


def bandpass(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x)


def lowpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), 400)
    x[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def swing(seed, length=0.28, lo=500, hi=3500):
    n = int(SR * length)
    noise = np.random.default_rng(seed).normal(size=n)
    # Sweep a band-pass upward then down: the "whoosh" of a blade.
    out = np.zeros(n)
    steps = 24
    for i in range(steps):
        a, b = i * n // steps, (i + 1) * n // steps
        phase = i / steps
        center = lo + (hi - lo) * np.sin(np.pi * phase)
        seg = bandpass(noise, center * 0.7, min(center * 1.4, SR / 2 - 100))[a:b]
        out[a:b] = seg
    shape = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return out * shape


def impact(seed, body_hz=95, crack_hz=2600, length=0.35):
    n = int(SR * length)
    t = np.arange(n) / SR
    r = np.random.default_rng(seed)
    thump = np.sin(2 * np.pi * body_hz * t * (1 - 0.35 * t / length)) * env(n, 0.002, 0.09, 3)
    crack = bandpass(r.normal(size=n), crack_hz * 0.5, crack_hz * 1.6) * env(n, 0.001, 0.03, 5)
    grit = lowpass(r.normal(size=n), 900) * env(n, 0.002, 0.12, 4) * 0.5
    return thump * 1.0 + crack * 0.7 + grit


def bone_hit(seed):
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    r = np.random.default_rng(seed)
    clack = bandpass(r.normal(size=n), 700, 2400) * env(n, 0.001, 0.05, 5)
    knock = np.sin(2 * np.pi * 420 * t) * env(n, 0.001, 0.05, 5) * 0.6
    thump = np.sin(2 * np.pi * 110 * t) * env(n, 0.002, 0.08, 4)
    return clack + knock + thump * 0.8


def clang(seed):
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    r = np.random.default_rng(seed)
    partials = [(523, 1.0, 0.35), (1377, 0.6, 0.25), (2210, 0.45, 0.18), (3150, 0.3, 0.12), (4020, 0.2, 0.08)]
    x = sum(a * np.sin(2 * np.pi * f * (1 + r.uniform(-0.01, 0.01)) * t) * env(n, 0.001, d, 3) for f, a, d in partials)
    hit = bandpass(r.normal(size=n), 1500, 6000) * env(n, 0.0005, 0.015, 5)
    return x + hit * 0.8


def thud(seed, length=0.3):
    n = int(SR * length)
    t = np.arange(n) / SR
    r = np.random.default_rng(seed)
    body = np.sin(2 * np.pi * 70 * t) * env(n, 0.002, 0.1, 4)
    wood = bandpass(r.normal(size=n), 250, 1200) * env(n, 0.001, 0.05, 5)
    return body + wood * 0.6


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(3):
        save(f"swing_{i + 1}", swing(10 + i, 0.26 + i * 0.03, 450 + i * 80, 3200 + i * 300), 0.55)
    save("swing_heavy", swing(20, 0.45, 250, 2200), 0.65)
    save("dodge", swing(30, 0.3, 300, 1400), 0.45)
    for i in range(3):
        save(f"hit_{i + 1}", impact(40 + i, 85 + i * 12, 2300 + i * 400), 0.85)
    for i in range(2):
        save(f"hit_bone_{i + 1}", bone_hit(50 + i), 0.8)
    save("block", clang(60), 0.7)
    save("thud", thud(70), 0.8)
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
