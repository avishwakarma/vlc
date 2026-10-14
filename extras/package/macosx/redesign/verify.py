#!/usr/bin/env python3
"""Static checks on the app bundle.

 1. No Mach-O load command / rpath / install name references /opt/homebrew, /usr/local or /Users/.
 2. Every dependency is a system library or an @rpath/@loader_path/@executable_path reference that
    resolves to an existing file inside the bundle.
Usage: verify.py <App.app>      (exit status 1 on any problem)
"""
import os, re, subprocess, sys
from pathlib import Path

BAD = ("/opt/homebrew", "/usr/local", "/Users/", "/opt/vlc-redesign")
app = Path(sys.argv[1]).resolve()
fw = app / "Contents/Frameworks"


def otool(flag, p):
    return subprocess.run(["otool", flag, str(p)], capture_output=True, text=True).stdout


problems, n = [], 0
for d, _, files in os.walk(app):
    for name in files:
        p = Path(d) / name
        if p.is_symlink() or not p.is_file():
            continue
        with open(p, "rb") as f:
            if f.read(4) not in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe"):
                continue
        n += 1
        for flag in ("-L", "-l"):
            out = otool(flag, p)
            for line in out.splitlines():
                if line.startswith(str(p)):
                    continue  # otool echoes the file name
                if any(b in line for b in BAD):
                    problems.append(f"{p.relative_to(app)}: {line.strip()}")
        rps = [re.match(r"\s*path (.*) \(offset", l).group(1)
               for l in otool("-l", p).splitlines() if l.strip().startswith("path ") and "offset" in l
               and "cmd LC_RPATH" in otool("-l", p)]
        # simple resolution check of dependencies
        for dep in otool("-L", p).splitlines()[1:]:
            m = re.match(r"\s*(\S.*?) \(", dep)
            if not m:
                continue
            dep = m.group(1)
            if dep.startswith(("/usr/lib/", "/System/")):
                continue
            if dep.startswith("@rpath/"):
                tail = dep[7:]
                ok = False
                for rp in rps:
                    base = rp.replace("@loader_path", str(p.parent)).replace("@executable_path", str(app / "Contents/MacOS"))
                    if (Path(os.path.normpath(base)) / tail).exists():
                        ok = True
                if not ok and (p.name == Path(tail).name or str(p).endswith(tail)):
                    ok = True  # self reference
                if not ok:
                    problems.append(f"{p.relative_to(app)}: unresolved {dep}")
            elif dep.startswith("@loader_path/") and (p.parent / dep[13:]).exists():
                pass
            else:
                problems.append(f"{p.relative_to(app)}: bad dependency {dep}")

print(f"scanned {n} Mach-O files")
if problems:
    print("\n".join(problems[:50]))
    print(f"FAIL: {len(problems)} problem(s)")
    sys.exit(1)
print("OK: no Homebrew/usr-local/Users references; all dependencies resolve inside the bundle")
