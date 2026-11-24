"""Generate the paper textures and placeholder pictures this shell uses. Run: python3 tools/make_assets.py"""
import math, random, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.join(os.path.dirname(__file__), "..", "img")
random.seed(7)

def paper(w, h, base=(238, 228, 206)):
    img = Image.new("RGB", (w, h), base)
    # Coarse blotches: low-frequency noise scaled up.
    for scale, amp in ((64, 10), (16, 6), (4, 5), (1, 7)):
        n = Image.effect_noise((max(1, w // scale), max(1, h // scale)), 40).resize((w, h), Image.BICUBIC)
        n = n.point(lambda v, a=amp: 128 + (v - 128) * a / 40)
        img = ImageChops.add(img, Image.merge("RGB", (n, n, n)), 1, -128)
    # Fibres: short faint strokes.
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(w * h // 900):
        x, y = random.uniform(0, w), random.uniform(0, h)
        a, l = random.uniform(0, math.pi), random.uniform(3, 14)
        c = random.choice(((150, 130, 100, 28), (255, 255, 245, 40)))
        d.line((x, y, x + l * math.cos(a), y + l * math.sin(a)), fill=c, width=1)
    return img.filter(ImageFilter.GaussianBlur(0.4))

def sky(w, h):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    stops = [(0.0, (52, 74, 120)), (0.45, (120, 130, 170)), (0.7, (226, 160, 140)), (1.0, (245, 200, 150))]
    for y in range(h):
        t = y / (h - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0)
                d.line((0, y, w, y), fill=tuple(int(a + (b - a) * k) for a, b in zip(c0, c1)))
                break
    return img

def hills(img, layers):
    w, h = img.size
    d = ImageDraw.Draw(img)
    for base, amp, color, seed in layers:
        r = random.Random(seed)
        ph = [r.uniform(0, 6.28) for _ in range(3)]
        pts = [(x, h * base - amp * (0.6 * math.sin(x / w * 5 + ph[0]) + 0.3 * math.sin(x / w * 13 + ph[1])
                                     + 0.1 * math.sin(x / w * 41 + ph[2]))) for x in range(0, w + 8, 8)]
        d.polygon(pts + [(w, h), (0, h)], fill=color)
    return img

def wallpaper(w, h):
    img = hills(sky(w, h), [(0.72, 60, (70, 80, 110), 1), (0.82, 50, (45, 55, 70), 2), (0.92, 40, (28, 34, 40), 3)])
    # Clouds: soft light ellipses.
    over = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(over)
    for _ in range(40):
        x, y = random.uniform(0, w), random.uniform(0, h * 0.55)
        rw, rh = random.uniform(80, 360), random.uniform(14, 40)
        d.ellipse((x - rw, y - rh, x + rw, y + rh), fill=(255, 225, 210, 30))
    img = Image.alpha_composite(img.convert("RGBA"), over.filter(ImageFilter.GaussianBlur(18)))
    return img.convert("RGB")

def photo(w, h):
    img = hills(sky(w, h), [(0.6, 18, (90, 105, 140), 4), (0.78, 22, (60, 90, 70), 5), (0.95, 14, (40, 60, 45), 6)])
    return img.filter(ImageFilter.GaussianBlur(0.6))

def cover(s):
    """An album-cover placeholder: a pencil-ish circle and lines on paper."""
    img = paper(s, s, (225, 215, 195))
    d = ImageDraw.Draw(img)
    for i in range(9):
        r = s * (0.12 + i * 0.04)
        d.ellipse((s / 2 - r, s / 2 - r, s / 2 + r, s / 2 + r), outline=(90, 80, 70), width=1)
    d.ellipse((s * 0.45, s * 0.45, s * 0.55, s * 0.55), fill=(200, 80, 70))
    return img

def grain(n=512):
    """Tileable grain for shaders/paper.frag: R fine tooth, G soft mottle, B fibres. Periodic by
    construction (filtered in the frequency domain, fibres drawn wrapped), so fract() tiles seamlessly."""
    import numpy as np
    rs = np.random.default_rng(7)
    fy, fx = np.meshgrid(np.fft.fftfreq(n), np.fft.fftfreq(n), indexing="ij")
    f = np.sqrt(fx ** 2 + fy ** 2) + 1e-6
    def band(power, lo=0.0):
        spec = np.fft.fft2(rs.standard_normal((n, n))) / f ** power * (f > lo)
        v = np.real(np.fft.ifft2(spec))
        v = (v - v.mean()) / (v.std() * 6) + 0.5
        return np.clip(v, 0, 1)
    r = band(0.35)
    g = band(1.6)
    img = Image.new("L", (n, n), 128)
    d = ImageDraw.Draw(img)
    for _ in range(1400):
        x, y = random.uniform(0, n), random.uniform(0, n)
        a, l = random.uniform(0, math.pi), random.uniform(4, 22)
        v = random.choice((70, 200, 230))
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d.line((x + ox, y + oy, x + ox + l * math.cos(a), y + oy + l * math.sin(a)), fill=v, width=1)
    b = np.asarray(img.filter(ImageFilter.GaussianBlur(0.5)), dtype=float) / 255
    rgb = (np.stack([r, g, b], -1) * 255).astype("uint8")
    return Image.fromarray(rgb, "RGB")

os.makedirs(OUT, exist_ok=True)
grain().save(f"{OUT}/grain.png")
wallpaper(3440, 1440).save(f"{OUT}/wallpaper.jpg", quality=90)
photo(320, 220).save(f"{OUT}/photo.png")
cover(240).save(f"{OUT}/cover.png")
print("ok")
