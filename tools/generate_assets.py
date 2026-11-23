#!/usr/bin/env python3
"""Generates the app icon and default alarm sound.

Existing files are never overwritten, so you can drop in your own
assets/icon/icon.png (1024x1024), assets/icon/icon_foreground.png
(transparent, bell inside the centre 60%) or assets/sounds/default_alarm.wav.
"""
import array
import math
import wave
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / 'assets' / 'icon'
SOUND_DIR = ROOT / 'assets' / 'sounds'

BLUE_TOP = (47, 123, 255)
BLUE_BOTTOM = (18, 63, 191)
SS = 2  # supersampling factor for smooth edges


def draw_bell(draw, scale, fill):
    """Bell authored on a 1024 grid, centred on the canvas."""
    def t(x, y):
        return ((512 + (x - 512) * scale) * SS, (512 + (y - 510) * scale) * SS)

    draw.ellipse([t(470, 173), t(554, 257)], fill=fill)                   # top knob
    draw.ellipse([t(302, 230), t(722, 650)], fill=fill)                   # dome
    draw.polygon([t(302, 440), t(722, 440), t(800, 710), t(224, 710)], fill=fill)  # body
    draw.rounded_rectangle([t(190, 690), t(834, 760)], radius=35 * scale * SS, fill=fill)  # rim
    draw.ellipse([t(447, 775), t(577, 860)], fill=fill)                   # clapper


def make_icon(path):
    size = 1024 * SS
    img = Image.new('RGB', (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        f = y / (size - 1)
        color = tuple(int(BLUE_TOP[i] + (BLUE_BOTTOM[i] - BLUE_TOP[i]) * f) for i in range(3))
        d.line([(0, y), (size, y)], fill=color)
    draw_bell(d, 0.9, (255, 255, 255))
    img.resize((1024, 1024), Image.LANCZOS).save(path)


def make_foreground(path):
    size = 1024 * SS
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw_bell(ImageDraw.Draw(img), 0.6, (255, 255, 255, 255))
    img.resize((1024, 1024), Image.LANCZOS).save(path)


def make_alarm(path):
    rate = 44100
    samples = array.array('h')

    def tone(freq, seconds):
        n = int(rate * seconds)
        for i in range(n):
            env = min(1.0, i / (0.01 * rate), (n - i) / (0.02 * rate))
            wave_value = (math.sin(2 * math.pi * freq * i / rate)
                          + 0.4 * math.sin(4 * math.pi * freq * i / rate)) / 1.4
            samples.append(int(32767 * 0.85 * env * wave_value))

    def silence(seconds):
        samples.extend([0] * int(rate * seconds))

    for freq in (988, 1319, 988, 1319):
        tone(freq, 0.16)
        silence(0.04)
    silence(0.5)

    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(samples.tobytes())


def main():
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    SOUND_DIR.mkdir(parents=True, exist_ok=True)
    for path, builder in (
        (ICON_DIR / 'icon.png', make_icon),
        (ICON_DIR / 'icon_foreground.png', make_foreground),
        (SOUND_DIR / 'default_alarm.wav', make_alarm),
    ):
        if path.exists():
            print(f'keep   {path.relative_to(ROOT)}')
        else:
            builder(path)
            print(f'create {path.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
