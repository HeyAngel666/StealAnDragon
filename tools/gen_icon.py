"""Gera o ícone (512x512) e a thumbnail (1920x1080) do jogo.

Uso:  python3 tools/gen_icon.py
Saída: assets/icon/icone.png e assets/icon/thumbnail.png
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
FONT = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"


def gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        a = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * a) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img


def rays(img, center, color, count=18, alpha=40):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    r = max(img.size) * 1.5
    for i in range(count):
        a0 = (i / count) * 2 * math.pi
        a1 = a0 + math.pi / count
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=color + (alpha,))
    img.paste(layer, (0, 0), layer)


def dragon(d, ox, oy, s, body=(220, 40, 40), belly=(255, 200, 90), wing=(150, 20, 30)):
    """Desenha um dragão de lado (olhando para a direita). s = escala."""
    def P(x, y):
        return (ox + x * s, oy + y * s)

    outline = (30, 10, 10)
    w = max(2, int(6 * s))
    # cauda
    tail = [P(-150, -10), P(-240, -30), P(-310, -70), P(-340, -100), P(-315, -50), P(-250, 20), P(-150, 90)]
    d.polygon(tail, fill=body, outline=outline, width=w)
    d.polygon([P(-330, -90), P(-370, -120), P(-345, -60), P(-310, -70)], fill=belly, outline=outline, width=w)
    # asa de trás
    d.polygon([P(-30, -60), P(-150, -220), P(-110, -150), P(-80, -170), P(-40, -110), P(0, -150), P(30, -70)], fill=tuple(int(c * 0.7) for c in wing), outline=outline, width=w)
    # pernas de trás
    d.ellipse([P(-130, 40), P(-50, 170)], fill=body, outline=outline, width=w)
    d.ellipse([P(-150, 150), P(-50, 195)], fill=belly, outline=outline, width=w)
    # corpo
    d.ellipse([P(-170, -80), P(110, 120)], fill=body, outline=outline, width=w)
    d.ellipse([P(-120, -10), P(90, 115)], fill=belly)
    # pescoço
    d.polygon([P(40, -40), P(120, -170), P(190, -150), P(110, 30)], fill=body, outline=outline, width=w)
    # pernas da frente
    d.ellipse([P(30, 40), P(100, 170)], fill=body, outline=outline, width=w)
    d.ellipse([P(20, 150), P(120, 195)], fill=belly, outline=outline, width=w)
    # cabeça
    d.ellipse([P(100, -240), P(250, -120)], fill=body, outline=outline, width=w)
    d.ellipse([P(190, -200), P(320, -125)], fill=body, outline=outline, width=w)
    d.ellipse([P(200, -160), P(315, -125)], fill=belly)
    # chifres
    d.polygon([P(130, -225), P(80, -320), P(165, -235)], fill=belly, outline=outline, width=w)
    d.polygon([P(170, -235), P(150, -330), P(205, -230)], fill=belly, outline=outline, width=w)
    # olho
    d.ellipse([P(200, -215), P(250, -170)], fill=(255, 255, 255), outline=outline, width=w)
    d.ellipse([P(222, -205), P(246, -178)], fill=(20, 20, 20))
    d.ellipse([P(228, -200), P(236, -192)], fill=(255, 255, 255))
    # narina e sorriso
    d.ellipse([P(290, -185), P(302, -173)], fill=outline)
    d.arc([P(220, -175), P(310, -130)], 10, 120, fill=outline, width=w)
    # asa da frente
    joint = P(70, -290)
    shoulder = P(40, -40)
    tips = [P(10, -440), P(-150, -390), P(-230, -230), P(-60, -60)]

    def scallop(a, b, depth=0.28, steps=8):
        # curva côncava entre duas pontas (puxada para a articulação)
        pts = []
        for k in range(1, steps):
            t = k / steps
            x = a[0] + (b[0] - a[0]) * t
            y = a[1] + (b[1] - a[1]) * t
            bow = math.sin(math.pi * t) * depth
            pts.append((x + (joint[0] - x) * bow, y + (joint[1] - y) * bow))
        return pts

    poly = [shoulder, joint, tips[0]]
    for a, b in zip(tips, tips[1:]):
        poly += scallop(a, b) + [b]
    poly += [shoulder]
    d.polygon(poly, fill=wing, outline=outline, width=w)
    tips = tips[:3]
    for tip in tips:
        d.line([joint, tip], fill=outline, width=w)
    d.line([shoulder, joint], fill=outline, width=w * 2)


def coins(d, cx, cy, s, n=9):
    for i in range(n):
        x = cx + (i % 5 - 2) * 46 * s + (i // 5) * 23 * s
        y = cy - (i // 5) * 26 * s
        d.ellipse([x - 26 * s, y - 14 * s, x + 26 * s, y + 14 * s], fill=(255, 200, 40), outline=(150, 90, 0), width=max(2, int(4 * s)))
        d.ellipse([x - 14 * s, y - 7 * s, x + 14 * s, y + 7 * s], outline=(255, 240, 150), width=max(1, int(3 * s)))


def text(img, txt, center, size, fill=(255, 220, 60), stroke=(40, 10, 10)):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, size)
    box = d.textbbox((0, 0), txt, font=font, stroke_width=int(size * 0.12))
    w, h = box[2] - box[0], box[3] - box[1]
    x, y = center[0] - w / 2 - box[0], center[1] - h / 2 - box[1]
    # sombra
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x + size * 0.06, y + size * 0.08), txt, font=font, fill=(0, 0, 0, 160), stroke_width=int(size * 0.12), stroke_fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.04))
    img.paste(shadow, (0, 0), shadow)
    d.text((x, y), txt, font=font, fill=fill, stroke_width=int(size * 0.12), stroke_fill=stroke)


def icon():
    S = 1024
    img = gradient(S, S, (255, 150, 40), (150, 20, 60)).convert("RGBA")
    rays(img, (S * 0.55, S * 0.45), (255, 240, 180), alpha=45)
    d = ImageDraw.Draw(img)
    coins(d, S * 0.5, S * 0.83, 2.2)
    dragon(d, S * 0.47, S * 0.55, 1.15)
    text(img, "ROUBE UM", (S * 0.5, S * 0.1), 120, fill=(255, 255, 255))
    text(img, "DRAGÃO!", (S * 0.5, S * 0.9), 170)
    img = img.resize((512, 512), Image.LANCZOS)
    img.convert("RGB").save(os.path.join(OUT, "icone.png"))


def thumbnail():
    W, H = 1920, 1080
    img = gradient(W, H, (90, 170, 255), (255, 150, 80)).convert("RGBA")
    rays(img, (W * 0.3, H * 0.5), (255, 255, 220), alpha=35)
    d = ImageDraw.Draw(img)
    # chão
    d.rectangle([0, H * 0.8, W, H], fill=(90, 170, 70))
    coins(d, W * 0.3, H * 0.88, 2.2)
    dragon(d, W * 0.3, H * 0.66, 0.95)
    # dragão menor sendo "roubado"
    dragon(d, W * 0.76, H * 0.66, 0.6, body=(60, 150, 230), belly=(200, 240, 255), wing=(30, 90, 170))
    text(img, "ROUBE UM DRAGÃO!", (W * 0.5, H * 0.11), 130)
    text(img, "Compre • Roube • Proteja", (W * 0.68, H * 0.32), 64, fill=(255, 255, 255))
    img.convert("RGB").save(os.path.join(OUT, "thumbnail.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icon()
    thumbnail()
    print("ok")
