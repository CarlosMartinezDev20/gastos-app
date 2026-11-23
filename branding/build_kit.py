"""Builds the Finomiau logo kit (SVG masters) in branding/svg/.

The mark: a "ficha" (an iOS-like superellipse, between a coin and a card) whose top corners rise into
ears, with two round eyes cut out. The wordmark is "finomiau" in Inter Display Black, set tight, with
the mark as the «o». Inside the wordmark and at 40 px or less the "small" cut is used (eyes 1.6x larger).

    python3 -m pip install fonttools   # once, in any venv
    python3 branding/build_kit.py      # from gastos-app/; then branding/render_kit.sh for the PNGs
"""
import math
import os

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "svg")
FONT = os.path.join(HERE, "..", "assets", "fonts", "inter", "InterDisplay-Black.ttf")

INK, LIME, WHITE, BLACK = "#1C1C1E", "#C8F04B", "#FFFFFF", "#000000"


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


# ---------------------------------------------------------------- geometry (256 × 256 box)
def area(pts):
    return sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(pts, pts[1:] + pts[:1])) / 2


def ear(outer, tip, inner, k):
    """Triangle with a rounded tip, wound clockwise on screen so it unites with the body (nonzero)."""
    if area([outer, tip, inner]) < 0:
        outer, inner = inner, outer

    def back(p, q, d):
        dx, dy = q[0] - p[0], q[1] - p[1]
        n = math.hypot(dx, dy)
        return q[0] - dx / n * d, q[1] - dy / n * d

    p1, p2 = back(outer, tip, k), back(inner, tip, k)
    return (f"M{f(outer[0])},{f(outer[1])} L{f(p1[0])},{f(p1[1])} Q{f(tip[0])},{f(tip[1])} "
            f"{f(p2[0])},{f(p2[1])} L{f(inner[0])},{f(inner[1])} Z")


def eye_ccw(cx, cy, r):
    """Counter-clockwise circle: a hole under the nonzero rule."""
    return (f"M{f(cx-r)},{f(cy)} A{f(r)},{f(r)} 0 1 0 {f(cx+r)},{f(cy)} "
            f"A{f(r)},{f(r)} 0 1 0 {f(cx-r)},{f(cy)} Z")


def superellipse_cw(cx, cy, a, b, n, steps=160):
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        pts.append((cx + a * math.copysign(abs(c) ** (2 / n), c), cy + b * math.copysign(abs(s) ** (2 / n), s)))
    if area(pts) < 0:
        pts.reverse()
    return "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts) + " Z"


def mirror(p):
    return 256 - p[0], p[1]


CX, CY, A, B = 128, 142, 100, 88
BODY = (CX - A, CY - B, CX + A, CY + B)  # body box, without the ears
EAR_TOP = CY - B - 26  # tip of the ears


def mark(small=False):
    body = superellipse_cw(CX, CY, A, B, 3.4)
    o, t, i = (CX - A + 6, CY - 30), (CX - A + 14, EAR_TOP), (CX - A + 76, CY - B + 4)
    ears = ear(o, t, i, 18) + " " + ear(mirror(o), mirror(t), mirror(i), 18)
    r, dx = (23, 38) if small else (14.5, 32)
    eyes = eye_ccw(CX - dx, 148, r) + " " + eye_ccw(CX + dx, 148, r)
    return f"{body} {ears} {eyes}"


# ---------------------------------------------------------------- app icon
def squircle(size=1024, n=5.0, steps=240):
    h = size / 2
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        pts.append(f"{f(h + h * math.copysign(abs(c) ** (2 / n), c))},{f(h + h * math.copysign(abs(s) ** (2 / n), s))}")
    return "M" + " L".join(pts) + " Z"


SQ = squircle()

DEFS = f"""
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2B2B2E"/><stop offset=".6" stop-color="{INK}"/><stop offset="1" stop-color="#111112"/></linearGradient>
  <radialGradient id="halo" cx=".5" cy=".52" r=".5"><stop offset="0" stop-color="{LIME}" stop-opacity=".16"/><stop offset="1" stop-color="{LIME}" stop-opacity="0"/></radialGradient>
  <linearGradient id="lime" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#DEFB7E"/><stop offset=".55" stop-color="{LIME}"/><stop offset="1" stop-color="#A9D12C"/></linearGradient>
  <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".28"/><stop offset=".55" stop-color="#fff" stop-opacity="0"/></linearGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".2"/><stop offset=".3" stop-color="#fff" stop-opacity="0"/></linearGradient>
  <filter id="shadow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="9"/></filter>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="16"/></filter>
  <clipPath id="tile"><path d="{SQ}"/></clipPath>"""


def placed(width, cy=528):
    """Transform that puts the mark's body `width` px wide, centred (a touch low: the ears weigh on top)."""
    s = width / (BODY[2] - BODY[0])
    cxb, cyb = (BODY[0] + BODY[2]) / 2, (BODY[1] + BODY[3]) / 2
    return f'transform="translate({f(512 - cxb * s)},{f(cy - cyb * s)}) scale({f(s)})"'


def lit_mark(d, width, effects=True):
    fx = (f'<path d="{d}" fill="#000" opacity=".55" filter="url(#shadow)" transform="translate(0,12)"/>'
          f'<path d="{d}" fill="{LIME}" opacity=".35" filter="url(#glow)"/>') if effects else ""
    return f'<g {placed(width)}>{fx}<path d="{d}" fill="url(#lime)"/><path d="{d}" fill="url(#sheen)"/></g>'


def svg(w, h, body, title="Finomiau"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(w)} {f(h)}" width="{f(w)}" height="{f(h)}">'
            f'<title>{title}</title>{body}</svg>\n')


BACKGROUND = '<rect width="1024" height="1024" fill="url(#bg)"/><ellipse cx="512" cy="540" rx="430" ry="400" fill="url(#halo)"/>'


def app_icon(rounded):
    inner = BACKGROUND + lit_mark(mark(), 560)
    if rounded:
        return svg(1024, 1024, f'<defs>{DEFS}</defs><g clip-path="url(#tile)">{inner}</g>'
                               f'<path d="{SQ}" fill="none" stroke="url(#rim)" stroke-width="5"/>')
    return svg(1024, 1024, f"<defs>{DEFS}</defs>{inner}")


def favicon():
    # small cut, bigger in the tile, no glow (it only muddies 16 px)
    return svg(1024, 1024, f'<defs>{DEFS}</defs><path d="{SQ}" fill="url(#bg)"/>{lit_mark(mark(True), 680, effects=False)}')


# Android adaptive icon: 108 dp layers, only the central 66 dp circle is safe -> body at 46 % of the canvas.
def adaptive_background():
    return svg(1024, 1024, f"<defs>{DEFS}</defs>{BACKGROUND}")


def adaptive_foreground():
    return svg(1024, 1024, f"<defs>{DEFS}</defs>{lit_mark(mark(), 470)}")


def adaptive_monochrome():
    return svg(1024, 1024, f'<g {placed(470)}><path d="{mark()}" fill="{WHITE}"/></g>')


# iOS 18 appearances: the system draws its own dark background / tint behind a transparent icon.
def ios_dark():
    return svg(1024, 1024, f"<defs>{DEFS}</defs>{lit_mark(mark(), 560)}")


def ios_tinted():
    return svg(1024, 1024, f'<g {placed(560)}><path d="{mark()}" fill="{WHITE}"/></g>')


def symbol(color, small=False):
    top = EAR_TOP + 5.5  # the rounded tips peak below their control point
    return svg(BODY[2] - BODY[0], BODY[3] - top,
               f'<path transform="translate({-BODY[0]},{-top})" fill="{color}" d="{mark(small)}"/>')


# ---------------------------------------------------------------- wordmark
font = TTFont(FONT)
gs = font.getGlyphSet()
cmap = font.getBestCmap()
UPM = font["head"].unitsPerEm


def gbounds(name):
    bp = BoundsPen(gs)
    gs[name].draw(bp)
    return bp.bounds


def wordmark(ink, mark_color, size=160, tracking=-0.03):
    sc = size / UPM
    pen = SVGPathPen(gs)
    x, base, prev = 0.0, 0.0, None
    top, bottom = 0.0, 0.0
    ob = gbounds(cmap[ord("o")])
    o_h = (ob[3] - ob[1]) * sc
    sym = ""
    for ch in "finomiau":
        name = cmap[ord(ch)]
        if prev == "f" and ch == "i":
            x += 0.035 * size  # keep the f's hook off the i's dot
        prev = ch
        if ch == "o":
            bw, bh = BODY[2] - BODY[0], BODY[3] - BODY[1]
            s = o_h * 1.02 / bh
            lsb = ob[0] * sc
            tx = x + lsb - BODY[0] * s
            ty = base - ob[3] * sc - o_h * 0.01 - BODY[1] * s
            sym = f'<path fill="{mark_color}" transform="translate({f(tx)},{f(ty)}) scale({f(s)})" d="{mark(True)}"/>'
            top = min(top, ty + (EAR_TOP + 5.5) * s)
            bottom = max(bottom, ty + BODY[3] * s)
            adv = 2 * lsb + bw * s
        else:
            gs[name].draw(TransformPen(pen, (sc, 0, 0, -sc, x, base)))
            b = gbounds(name)
            top, bottom = min(top, base - b[3] * sc), max(bottom, base - b[1] * sc)
            right = x + b[2] * sc
            adv = gs[name].width * sc
        x += adv + tracking * size
    width = right
    h = bottom - top
    body = (f'<g transform="translate(0,{f(-top)})"><path fill="{ink}" d="{pen.getCommands()}"/>{sym}</g>')
    return svg(width, h, body)


FILES = {
    "finomiau-app-icon.svg": app_icon(rounded=False),
    "finomiau-app-icon-rounded.svg": app_icon(rounded=True),
    "finomiau-favicon.svg": favicon(),
    "android-adaptive-background.svg": adaptive_background(),
    "android-adaptive-foreground.svg": adaptive_foreground(),
    "android-adaptive-monochrome.svg": adaptive_monochrome(),
    "ios-dark.svg": ios_dark(),
    "ios-tinted.svg": ios_tinted(),
    "finomiau-symbol-lime.svg": symbol(LIME),
    "finomiau-symbol-ink.svg": symbol(INK),
    "finomiau-symbol-black.svg": symbol(BLACK),
    "finomiau-symbol-white.svg": symbol(WHITE),
    "finomiau-symbol-small-lime.svg": symbol(LIME, True),
    "finomiau-symbol-small-ink.svg": symbol(INK, True),
    "finomiau-symbol-small-black.svg": symbol(BLACK, True),
    "finomiau-symbol-small-white.svg": symbol(WHITE, True),
    "finomiau-wordmark-on-dark.svg": wordmark("#F7F7F8", LIME),
    "finomiau-wordmark-on-light.svg": wordmark(INK, INK),
    "finomiau-wordmark-black.svg": wordmark(BLACK, BLACK),
    "finomiau-wordmark-white.svg": wordmark(WHITE, WHITE),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, content in FILES.items():
        with open(os.path.join(OUT, name), "w") as fh:
            fh.write(content)
    print(f"{len(FILES)} files in {OUT}")
