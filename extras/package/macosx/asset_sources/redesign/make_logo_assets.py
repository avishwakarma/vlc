#!/usr/bin/env python3
# Derive the in-app cone assets from logo.svg / logo-white.svg (Figma nodes 10004:14787 / 10004:14788).
# Usage: make_logo_assets.py   (run from anywhere; needs rsvg-convert and iconutil for the PNG/icns steps)
#  - cone.svg                       24x24 box, cone 21px tall centred, orange   -> pixmaps/misc/cone.svg
#  - svg_icons "vlc.svg"            same, accent placeholder #FF8800           -> pixmaps/svg_icons/vlc.svg
#  - tray.svg                       same, white monochrome (macOS template)    -> pixmaps/misc/tray.svg
#  - app_icon.svg                   rewritten with the logo on the dark tile
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
QT = os.path.join(HERE, "../../../../../modules/gui/qt/pixmaps")
W, H = 105.75, 123.38


def paths(name, fill):
    t = open(os.path.join(HERE, name)).read()
    ds = re.findall(r'<path d="([^"]+)"', t)
    return "\n".join('    <path d="%s" fill="%s"/>' % (d, fill) for d in ds)


def box(name, fill, height=21.0, size=24):
    s = height / H
    tx, ty = (size - W * s) / 2, (size - height) / 2
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" fill="none">\n'
            '  <g transform="translate(%.3f %.3f) scale(%.5f)">\n%s\n  </g>\n</svg>\n'
            % (size, size, size, size, tx, ty, s, paths(name, fill)))


def write(p, s):
    open(os.path.join(HERE, p), "w").write(s)


write("cone.svg", box("logo.svg", "#D37918"))
write(QT + "/misc/cone.svg", box("logo.svg", "#D37918"))
write(QT + "/svg_icons/vlc.svg", box("logo.svg", "#FF8800"))
write(QT + "/misc/tray.svg", box("logo-white.svg", "#FFFFFF", height=24.0))

# app icon: keep the tile (everything up to the cone group), swap the cone
a = open(os.path.join(HERE, "app_icon.svg")).read()
head = a[:a.index("  <!-- designer's cone")]
h = 470.0
s = h / H
cone = ('  <!-- redesigned logo (Juxtopposed), flat #D37918, ~57%% of tile height -->\n'
        '  <g transform="translate(512 512) scale(%.4f) translate(%.3f %.3f)">\n%s\n  </g>\n</svg>\n'
        % (s, -W / 2, -H / 2, paths("logo.svg", "#D37918")))
write("app_icon.svg", head + cone)
