#!/usr/bin/env python3
# Check that every SVG listed in svgicons.qrc exists, parses, has a 24x24
# viewBox and only uses the expected placeholder colours.
# Usage: validate.py   (stdlib only)
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
QRC = os.path.join(HERE, "..", "..", "svgicons.qrc")
ALLOWED = {"#FF00FF", "#FF8800", "#00FFFF", "#303030", "#373737"}
PAINT_ATTRS = ("fill", "stroke", "stop-color")


def main():
    errors = 0
    listed = set()
    root = ET.parse(QRC).getroot()
    for f in root.iter("file"):
        listed.add(f.get("alias"))
        path = os.path.join(os.path.dirname(QRC), f.text)
        try:
            svg = ET.parse(path).getroot()
        except (OSError, ET.ParseError) as e:
            print("%s: %s" % (f.text, e)); errors += 1; continue
        if svg.get("viewBox") != "0 0 24 24":
            print("%s: viewBox %r" % (f.text, svg.get("viewBox"))); errors += 1
        for el in svg.iter():
            for a in PAINT_ATTRS:
                v = el.get(a)
                if v is None or v.lower() == "none":
                    continue
                if v.upper() not in ALLOWED:
                    print("%s: unexpected %s=%s" % (f.text, a, v)); errors += 1
            if el.get("id") is not None:
                print("%s: leftover id" % f.text); errors += 1
    on_disk = {f for f in os.listdir(HERE) if f.endswith(".svg")}
    for f in sorted(on_disk ^ listed):
        print("%s: not in sync with svgicons.qrc" % f); errors += 1
    print("%d icons checked, %d problems" % (len(listed), errors))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
