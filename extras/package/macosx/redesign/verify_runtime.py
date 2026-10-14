#!/usr/bin/env python3
"""Runtime check: launch the app with a sanitized environment and DYLD_PRINT_LIBRARIES=1, play a media
file for a few seconds, then assert that every loaded image comes from the bundle, /System or /usr/lib.
Usage: verify_runtime.py <App.app> <media file> [seconds]"""
import os, re, signal, subprocess, sys, tempfile, time
from pathlib import Path

app = Path(sys.argv[1]).resolve()
media = sys.argv[2]
secs = float(sys.argv[3]) if len(sys.argv) > 3 else 12
home = tempfile.mkdtemp(prefix="vlcredesign-home-")
env = {"HOME": home, "CFFIXED_USER_HOME": home, "PATH": "/usr/bin:/bin", "DYLD_PRINT_LIBRARIES": "1"}
log = open(os.path.join(home, "run.log"), "w")
p = subprocess.Popen([str(app / "Contents/MacOS/VLC"), "-vv", "--no-qt-privacy-ask", media],
                     env=env, stdout=log, stderr=subprocess.STDOUT)
time.sleep(secs)
kids = subprocess.run(["pgrep", "-P", str(p.pid)], capture_output=True, text=True).stdout.split()
for pid in [p.pid] + [int(k) for k in kids]:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
p.wait(timeout=20)
text = open(os.path.join(home, "run.log"), errors="replace").read()
# Output of several processes (VLC + vlc-preparser) can interleave mid-line: a path followed by another
# "dyld[" on the same line is truncated and is re-printed in full elsewhere, so skip it.
imgs = set(m.group(1) for m in re.finditer(r"dyld\[\d+\]: <[0-9A-F-]{36}> (/[^\n]*?)(?:\n|$)", text)
           if "dyld[" not in m.group(1))
real = lambda x: os.path.realpath(x)
root = real(str(app))
bad = sorted(i for i in imgs if not (i.startswith(("/System/", "/usr/lib/")) or real(i).startswith(root + "/")))
inside = sum(1 for i in imgs if real(i).startswith(root + "/"))
qt_ok = 'using interface module "qt"' in text
qml_err = len(re.findall(r"(?i)qml.*(error|not installed)|module .* is not installed", text))
print(f"{len(imgs)} images loaded ({inside} from the bundle); qt interface: {'yes' if qt_ok else 'NO'}; qml errors: {qml_err}")
if bad:
    print("FAIL, loaded from outside the bundle:\n  " + "\n  ".join(bad[:30]))
    sys.exit(1)
if not qt_ok or qml_err:
    sys.exit("FAIL: qt interface missing or QML errors")
print("OK: every loaded library is inside the bundle, /System or /usr/lib")
