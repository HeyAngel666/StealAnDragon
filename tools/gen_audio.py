"""Gera todos os efeitos sonoros e a música do jogo (sintetizados do zero).

Uso:  python3 tools/gen_audio.py
Saída: assets/audio/*.ogg  (envie para o Roblox e cole os IDs em src/shared/Sounds.lua)
Requer: numpy e ffmpeg.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, release=0.1, dur=None):
    """Envelope simples attack/decay exponencial."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-t / max(release, 1e-4))
    return a * d


def tone(freq, dur, kind="sine", vol=1.0):
    t = t_axis(dur)
    if callable(freq):
        phase = 2 * np.pi * np.cumsum(freq(t)) / SR
    else:
        phase = 2 * np.pi * freq * t
    if kind == "sine":
        w = np.sin(phase)
    elif kind == "square":
        w = np.sign(np.sin(phase)) * 0.6
    elif kind == "saw":
        w = 2 * ((phase / (2 * np.pi)) % 1) - 1
    elif kind == "tri":
        w = 2 * np.abs(2 * ((phase / (2 * np.pi)) % 1) - 1) - 1
    else:
        raise ValueError(kind)
    return w * vol


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    # filtro de 1 polo aplicado duas vezes
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    for _ in range(2):
        acc = 0.0
        out = np.empty_like(x)
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            out[i] = acc
        x = out
    return x


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def reverb(x, amount=0.3):
    """Eco simples com várias repetições (dá sensação de espaço)."""
    taps = ((0.031, 0.5), (0.047, 0.4), (0.071, 0.3), (0.113, 0.22))
    tail = int(SR * 0.6)
    out = np.zeros(len(x) + tail)
    out[: len(x)] += x
    for delay, gain in taps:
        for k in range(1, 6):
            d = int(SR * delay * k)
            end = min(len(out), d + len(x))
            out[d:end] += x[: end - d] * (gain**k) * amount
    return out


def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


def normalize(x, peak=0.9):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def fade(x, ms=8):
    n = int(SR * ms / 1000)
    if len(x) > 2 * n:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = fade(normalize(x))
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out_path = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "5", out_path], check=True)
    os.remove(wav_path)
    print("ok", out_path, f"{len(x)/SR:.2f}s")


def note(n):
    """Número MIDI -> frequência."""
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------------------------------------------------------- efeitos

def sfx_coin():
    a = tone(note(83), 0.07, "square") * env(int(SR * 0.07), 0.002, 0.05)
    b = tone(note(88), 0.25, "square") * env(int(SR * 0.25), 0.002, 0.1)
    buf = np.zeros(int(SR * 0.35))
    place(buf, a, 0)
    place(buf, b, 0.07)
    return buf


def sfx_buy():
    buf = np.zeros(int(SR * 0.6))
    for i, n in enumerate((72, 76, 79, 84)):
        x = tone(note(n), 0.25, "tri") * env(int(SR * 0.25), 0.003, 0.12)
        place(buf, x, i * 0.07)
    return reverb(buf, 0.25)


def sfx_steal():
    dur = 0.6
    t = t_axis(dur)
    sweep = tone(lambda tt: 300 + 900 * (tt / dur) ** 2, dur, "saw") * 0.4
    sweep = lowpass(sweep, 2500) * env(len(t), 0.05, 0.4)
    pluck = tone(note(64), 0.3, "square") * env(int(SR * 0.3), 0.002, 0.08)
    buf = np.zeros(int(SR * 0.8))
    place(buf, sweep, 0)
    place(buf, pluck, 0.45)
    return buf


def sfx_alarm():
    dur = 1.6
    t = t_axis(dur)
    f = np.where((t * 3) % 1 < 0.5, 700, 950)
    w = tone(lambda tt: np.where((tt * 3) % 1 < 0.5, 700, 950), dur, "square") * 0.5
    w = lowpass(w, 4000)
    _ = f
    return w * np.clip((dur - t) * 4, 0, 1)


def sfx_lock():
    thump = tone(lambda tt: 160 * np.exp(-tt * 20) + 60, 0.25, "sine") * env(int(SR * 0.25), 0.001, 0.08)
    click = highpass(noise(0.04), 2000) * env(int(SR * 0.04), 0.001, 0.01)
    clank = tone(note(76), 0.3, "tri") * env(int(SR * 0.3), 0.001, 0.06) * 0.5
    buf = np.zeros(int(SR * 0.45))
    place(buf, click, 0)
    place(buf, thump, 0.02)
    place(buf, clank, 0.05)
    return buf


def sfx_unlock():
    click = highpass(noise(0.03), 2000) * env(int(SR * 0.03), 0.001, 0.01)
    chirp = tone(lambda tt: 500 + 1500 * tt / 0.25, 0.25, "tri") * env(int(SR * 0.25), 0.01, 0.1)
    buf = np.zeros(int(SR * 0.4))
    place(buf, click, 0)
    place(buf, chirp, 0.05)
    return buf


def sfx_slap():
    n = noise(0.18)
    n = lowpass(n, 3500) * env(len(n), 0.001, 0.03)
    body = tone(lambda tt: 220 * np.exp(-tt * 30) + 80, 0.12, "sine") * env(int(SR * 0.12), 0.001, 0.04)
    buf = np.zeros(int(SR * 0.25))
    place(buf, n, 0)
    place(buf, body * 0.8, 0)
    return buf


def sfx_roar():
    dur = 1.8
    t = t_axis(dur)
    vib = 1 + 0.06 * np.sin(2 * np.pi * 7 * t)
    base = tone(lambda tt: (85 + 25 * np.sin(np.pi * tt / dur)) * (1 + 0.06 * np.sin(2 * np.pi * 7 * tt)), dur, "saw")
    growl = base * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t))
    rough = lowpass(noise(dur), 900) * 0.8
    x = lowpass(growl + rough, 1400)
    shape = np.clip(t / 0.25, 0, 1) * np.clip((dur - t) / 0.7, 0, 1)
    _ = vib
    return reverb(x * shape, 0.35)


def sfx_rebirth():
    buf = np.zeros(int(SR * 2.0))
    notes = (60, 64, 67, 72, 76, 79, 84, 88)
    for i, n in enumerate(notes):
        x = (tone(note(n), 0.6, "sine") + 0.3 * tone(note(n + 12), 0.6, "sine")) * env(int(SR * 0.6), 0.005, 0.3)
        place(buf, x, i * 0.09)
    shimmer = highpass(noise(1.4), 6000) * env(int(SR * 1.4), 0.3, 0.5) * 0.15
    place(buf, shimmer, 0.2)
    return reverb(buf, 0.45)


def sfx_error():
    buf = np.zeros(int(SR * 0.4))
    for i, n in enumerate((50, 46)):
        x = lowpass(tone(note(n), 0.16, "square"), 1800) * env(int(SR * 0.16), 0.003, 0.1)
        place(buf, x, i * 0.15)
    return buf


def sfx_click():
    x = tone(note(96), 0.05, "sine") * env(int(SR * 0.05), 0.001, 0.012)
    return x


def sfx_freeze():
    buf = np.zeros(int(SR * 1.0))
    for i in range(10):
        n = 100 - i * 2 + rng.integers(-2, 3)
        x = tone(note(n), 0.3, "sine") * env(int(SR * 0.3), 0.002, 0.08) * 0.6
        place(buf, x, i * 0.05)
    hiss = highpass(noise(0.8), 5000) * env(int(SR * 0.8), 0.05, 0.3) * 0.3
    place(buf, hiss, 0)
    return reverb(buf, 0.4)


def sfx_explosion():
    dur = 1.6
    n = noise(dur)
    boom = lowpass(n, 400) * env(len(n), 0.002, 0.45) * 2.5
    crack = lowpass(n, 3000) * env(len(n), 0.001, 0.08)
    sub = tone(lambda tt: 60 * np.exp(-tt * 3) + 30, dur, "sine") * env(len(n), 0.002, 0.4)
    return boom + crack + sub


def sfx_event():
    buf = np.zeros(int(SR * 1.6))
    seq = [(67, 0.0, 0.15), (67, 0.17, 0.15), (67, 0.34, 0.15), (72, 0.52, 0.9)]
    for n, at, d in seq:
        for off in (0, 4, 7):
            x = lowpass(tone(note(n + off), d + 0.2, "saw"), 3000) * env(int(SR * (d + 0.2)), 0.02, d * 0.8)
            place(buf, x * 0.35, at)
    return reverb(buf, 0.35)


def sfx_reward():
    buf = np.zeros(int(SR * 1.1))
    for i, n in enumerate((79, 84, 88, 91, 96)):
        x = tone(note(n), 0.5, "sine") * env(int(SR * 0.5), 0.002, 0.2)
        place(buf, x, i * 0.06)
    return reverb(buf, 0.4)


# ---------------------------------------------------------------- música

def music_theme():
    bpm = 120
    beat = 60 / bpm
    bars = 16
    total = bars * 4 * beat
    buf = np.zeros(int(SR * total) + SR)

    # progressão: Am F C G (em semínimas, 4 tempos por acorde)
    chords = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]
    melody = [
        76, 74, 72, 74, 76, 76, 76, -1, 74, 74, 74, -1, 76, 79, 79, -1,
        76, 74, 72, 74, 76, 76, 76, 76, 74, 74, 76, 74, 72, -1, -1, -1,
        81, -1, 79, 77, 76, -1, 72, -1, 74, 76, 77, 79, 76, -1, -1, -1,
        81, -1, 79, 77, 76, 77, 79, 81, 79, 77, 76, 74, 72, -1, -1, -1,
    ]
    for bar in range(bars):
        chord = chords[bar % 4]
        t0 = bar * 4 * beat
        # baixo
        for b in range(4):
            n = chord[0] - 12
            x = lowpass(tone(note(n), beat * 0.9, "saw"), 600) * env(int(SR * beat * 0.9), 0.005, 0.25)
            place(buf, x * 0.5, t0 + b * beat)
        # arpejo
        for s in range(8):
            n = chord[s % 3] + (12 if s >= 4 else 0)
            x = tone(note(n), beat * 0.45, "square") * env(int(SR * beat * 0.45), 0.003, 0.08)
            place(buf, x * 0.12, t0 + s * beat / 2)
        # bateria
        for b in range(4):
            kick = tone(lambda tt: 120 * np.exp(-tt * 25) + 45, 0.2, "sine") * env(int(SR * 0.2), 0.001, 0.08)
            if b in (0, 2):
                place(buf, kick * 0.9, t0 + b * beat)
            else:
                snare = lowpass(noise(0.18), 5000) * env(int(SR * 0.18), 0.001, 0.05)
                place(buf, snare * 0.35, t0 + b * beat)
            for h in range(2):
                hat = highpass(noise(0.04), 7000) * env(int(SR * 0.04), 0.001, 0.01)
                place(buf, hat * 0.12, t0 + b * beat + h * beat / 2)
    # melodia (colcheias), toca nas últimas 8 barras e repete
    step = beat / 2
    for rep in range(2):
        for i, n in enumerate(melody):
            if n < 0:
                continue
            at = rep * len(melody) * step + i * step
            if at >= total:
                break
            x = (tone(note(n), step * 0.95, "tri") * 0.8 + tone(note(n) * 1.003, step * 0.95, "square") * 0.15)
            x *= env(int(SR * step * 0.95), 0.01, 0.2)
            place(buf, x * 0.3 * (0.5 if rep == 0 else 1), at)
    buf = buf[: int(SR * total)]
    return buf


def main():
    sounds = {
        "moeda": sfx_coin,
        "compra": sfx_buy,
        "roubo": sfx_steal,
        "alarme": sfx_alarm,
        "trava": sfx_lock,
        "destrava": sfx_unlock,
        "tapa": sfx_slap,
        "rugido": sfx_roar,
        "rebirth": sfx_rebirth,
        "erro": sfx_error,
        "clique": sfx_click,
        "congelar": sfx_freeze,
        "explosao": sfx_explosion,
        "evento": sfx_event,
        "presente": sfx_reward,
        "musica_tema": music_theme,
    }
    for name, fn in sounds.items():
        save(name, fn())


if __name__ == "__main__":
    main()
