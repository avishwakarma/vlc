#!/usr/bin/env python3
# Normalize the Figma-exported icon SVGs for the VLC Qt interface.
#  - viewBox -> "0 0 24 24" (the Figma export keeps sheet coordinates, so the
#    content is wrapped in a translate() instead of rewriting every path)
#  - recolour to the SVGColorImage placeholders
#  - strip ids and empty wrapper groups
# Usage: normalize.py SRC_DIR [DST_DIR]   (stdlib only)
# SRC_DIR is the directory holding the Figma export (.redesign/assets/icons).
import os
import re
import sys

COLOR_MAP = {
    "#8F8F8F": "#FF00FF",  # color1  (foreground)
    "#D37918": "#FF8800",  # accent
    "#AB6314": "#00FFFF",  # color2  (accent dim)
}
# Kept as is: neutral colours used by the divider and thumbnail placeholders.
KEEP = {"#303030", "#373737"}

HERE = os.path.dirname(os.path.abspath(__file__))


def normalize(text, name):
    m = re.search(r'viewBox="\s*([-\d.]+)[ ,]+([-\d.]+)[ ,]+24[ ,]+24\s*"', text)
    if not m:
        raise ValueError("%s: unexpected viewBox" % name)
    x, y = float(m.group(1)), float(m.group(2))

    inner = re.search(r"<svg[^>]*>(.*)</svg>", text, re.S).group(1)
    # drop ids
    inner = re.sub(r'\s+id="[^"]*"', "", inner)
    # drop attribute-less wrapper groups
    prev = None
    while prev != inner:
        prev = inner
        inner = re.sub(r"<g>\s*(.*?)\s*</g>", r"\1", inner, flags=re.S)
    # normalise self-closing spacing
    inner = re.sub(r"\s+/>", "/>", inner)
    # recolour
    def recolor(mm):
        c = mm.group(2).upper()
        return '%s="%s"' % (mm.group(1), COLOR_MAP.get(c, mm.group(2)))
    inner = re.sub(r'\b(fill|stroke)="(#[0-9A-Fa-f]{6})"', recolor, inner)

    lines = [l.strip() for l in inner.strip().splitlines() if l.strip()]
    body = "\n".join("  " + l for l in lines)
    if x or y:
        fmt = lambda v: ("%.3f" % -v).rstrip("0").rstrip(".")
        body = '  <g transform="translate(%s %s)">\n%s\n  </g>' % (
            fmt(x), fmt(y), "\n".join("  " + l for l in body.splitlines()))
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
            'viewBox="0 0 24 24" fill="none">\n%s\n</svg>\n' % body)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__ or "usage: normalize.py SRC_DIR [DST_DIR]")
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else HERE
    n = 0
    for f in sorted(os.listdir(src)):
        if not f.endswith(".svg"):
            continue
        with open(os.path.join(src, f), encoding="utf-8") as fh:
            out = normalize(fh.read(), f)
        with open(os.path.join(dst, f), "w", encoding="utf-8") as fh:
            fh.write(out)
        n += 1
    # regenerate the resource file next to assets.qrc
    qrc = os.path.join(HERE, "..", "..", "svgicons.qrc")
    names = sorted(f for f in os.listdir(dst) if f.endswith(".svg"))
    with open(qrc, "w", encoding="utf-8") as fh:
        fh.write('<RCC>\n    <qresource prefix="/svgicons">\n')
        for f in names:
            fh.write('        <file alias="%s">pixmaps/svg_icons/%s</file>\n' % (f, f))
        fh.write("    </qresource>\n</RCC>\n")
    print("normalized %d icons into %s" % (n, dst))


if __name__ == "__main__":
    main()
