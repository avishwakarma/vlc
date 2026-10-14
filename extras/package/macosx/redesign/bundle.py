#!/usr/bin/env python3
"""Assemble a self-contained, ad-hoc signed "VLC Redesign (unofficial).app".

Input : a `meson install` staging tree (DESTDIR) of the Meson build.
Output: <out>/VLC Redesign (unofficial).app

Layout produced (VLC's src/darwin/dirs.m finds everything via the bundle, no env vars):
  Contents/MacOS/VLC                 main binary (vlc)
  Contents/MacOS/vlc-qt-check ...    libexec helpers (VLC_PKG_LIBEXEC_DIR == auxiliary executables)
  Contents/Frameworks/libvlc*.dylib, third-party dylibs, Qt*.framework
  Contents/Frameworks/plugins/<cat>/*.dylib + plugins.dat   (VLC_PKG_LIB_DIR/plugins)
  Contents/PlugIns/{platforms,imageformats,...}              Qt plugins
  Contents/Resources/{VLC.icns,qt.conf,qml/,share/}          Qt QML imports (Qt only; VLC's own QML is compiled
                                                             into libqt_plugin.dylib)

Every Mach-O is relocated: non-system dependencies are copied into Frameworks, install names become
@rpath/..., all LC_RPATHs are replaced by one relative rpath, then everything is signed inside-out.
"""
import argparse
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

APP_NAME = "VLC Redesign (unofficial).app"
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]

QT_ROOT = Path(os.environ.get("QT_ROOT", "/opt/homebrew/share/qt"))
# Where non-system dependencies may live. Anything else non-system is an error.
EXTRA_LIB_DIRS = [
    "/opt/homebrew/lib",
    "/usr/local/lib",
    str(Path.home() / "WebRoot/personal/vlc-deps/prefix/lib"),
]

QT_PLUGINS = {
    "platforms": ["libqcocoa.dylib"],
    "imageformats": ["libqsvg.dylib", "libqjpeg.dylib", "libqgif.dylib", "libqico.dylib",
                     "libqicns.dylib", "libqtiff.dylib", "libqwebp.dylib"],
    "iconengines": ["libqsvgicon.dylib"],
    "styles": ["libqmacstyle.dylib"],
    "tls": ["libqsecuretransportbackend.dylib", "libqcertonlybackend.dylib"],
    "networkinformation": ["libqscnetworkreachability.dylib"],
}
# QML style modules we never need (VLC draws everything itself on top of Basic).
QML_DROP = {"Material", "Universal", "Imagine", "iOS", "FluentWinUI3", "Fusion"}


def run(*cmd, check=True, quiet=False):
    r = subprocess.run([str(c) for c in cmd], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"{' '.join(map(str, cmd))}\n{r.stderr}{r.stdout}")
    return r.stdout


def is_macho(p: Path):
    if p.is_symlink() or not p.is_file():
        return False
    with open(p, "rb") as f:
        m = f.read(4)
    return m in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xfe\xed\xfa\xcf")


def macho_files(root: Path):
    for d, _, files in os.walk(root):
        for n in files:
            p = Path(d) / n
            if is_macho(p):
                yield p


def deps_of(p: Path):
    out = run("otool", "-L", p).splitlines()[1:]
    return [re.match(r"\s*(\S.*?) \(", l).group(1) for l in out if "(" in l]


def rpaths_of(p: Path):
    out = run("otool", "-l", p).splitlines()
    res = []
    for i, l in enumerate(out):
        if l.strip() == "cmd LC_RPATH":
            res.append(re.match(r"\s*path (.*) \(offset", out[i + 2]).group(1))
    return res


def install_id(p: Path):
    out = run("otool", "-D", p).splitlines()
    return out[1] if len(out) > 1 else None


def is_system(dep):
    return dep.startswith(("/usr/lib/", "/System/", "/Library/Apple/"))


class Bundler:
    def __init__(self, app: Path):
        self.app = app
        self.contents = app / "Contents"
        self.fw = self.contents / "Frameworks"
        self.macos = self.contents / "MacOS"
        self.copied = {}  # dst name -> source realpath (conflict detection)

    # ---- resolution -------------------------------------------------------
    def resolve(self, dep, owner: Path, owner_orig_rpaths):
        """Return a real path for a dependency reference, or None."""
        if dep.startswith("@loader_path/"):
            c = owner.parent / dep[len("@loader_path/"):]
            return c if c.exists() else None
        if dep.startswith("@executable_path/"):
            c = self.macos / dep[len("@executable_path/"):]
            return c if c.exists() else None
        if dep.startswith("@rpath/"):
            tail = dep[len("@rpath/"):]
            # already inside the bundle?
            for d in [self.fw]:
                if (d / tail).exists():
                    return d / tail
            for rp in owner_orig_rpaths:
                rp = rp.replace("@loader_path", str(owner.parent)).replace("@executable_path", str(self.macos))
                if (Path(rp) / tail).exists():
                    return Path(rp) / tail
            for d in EXTRA_LIB_DIRS + self.extra_search:
                if (Path(d) / tail).exists():
                    return Path(d) / tail
            # Homebrew Qt: frameworks live in /opt/homebrew/opt/<qt module>/lib
            for d in Path("/opt/homebrew/opt").glob("qt*/lib"):
                if (d / tail).exists():
                    return d / tail
            return None
        c = Path(dep)
        return c if c.exists() else None

    extra_search = []

    def in_bundle(self, p: Path):
        try:
            Path(os.path.realpath(p)).relative_to(os.path.realpath(self.app))
            return True
        except ValueError:
            return False

    # ---- copying ----------------------------------------------------------
    def bring_in(self, src: Path):
        """Copy a dependency into Frameworks; return new @rpath reference."""
        real = Path(os.path.realpath(src))
        m = re.search(r"(.*/(\w+)\.framework)/", str(real))
        if m:  # framework: copy once, keep Versions/A/<name> structure
            fwdir, name = Path(m.group(1)), m.group(2)
            dst = self.fw / f"{name}.framework"
            if not dst.exists():
                shutil.copytree(fwdir, dst, symlinks=True,
                                ignore=shutil.ignore_patterns("Headers", "*.prl", "*.dSYM", "Modules"))
                for hd in dst.rglob("Headers"):
                    if hd.is_symlink():
                        hd.unlink()
            rel = os.path.relpath(real, fwdir)
            return f"@rpath/{name}.framework/{rel}", dst / rel
        name = Path(src).name
        # use the reference name (e.g. libavcodec.62.dylib), not the fully-versioned file name
        dst = self.fw / name
        if name in self.copied and self.copied[name] != real:
            raise RuntimeError(f"name clash {name}: {self.copied[name]} vs {real}")
        if not dst.exists():
            shutil.copy2(real, dst)
            os.chmod(dst, 0o755)
            self.copied[name] = real
        return f"@rpath/{name}", dst

    # ---- main relocation loop --------------------------------------------
    def relocate(self):
        done = set()
        queue = list(macho_files(self.contents))
        orig_rpaths = {}
        while queue:
            f = queue.pop()
            if f in done:
                continue
            done.add(f)
            rps = orig_rpaths.get(f) or rpaths_of(f)
            changes = []
            for dep in deps_of(f):
                if is_system(dep) or dep.startswith("@rpath/") and (self.fw / dep[7:]).exists():
                    continue
                if dep == install_id(f):
                    continue
                base = Path(dep).name
                if ".framework/" not in dep and (self.fw / base).exists():
                    changes.append((dep, "@rpath/" + base))  # e.g. libvlccore installed under the meson prefix
                    continue
                src = self.resolve(dep, f, rps)
                if src is None:
                    raise RuntimeError(f"{f}: cannot resolve {dep}")
                if self.in_bundle(src) and not dep.startswith("@rpath/"):
                    # inside bundle, but referenced by relative/absolute path -> @rpath
                    ref = "@rpath/" + os.path.relpath(src, self.fw)
                    new = src
                else:
                    ref, new = self.bring_in(src)
                    if new.name not in ("",) and new not in done:
                        orig_rpaths[new] = rpaths_of(new)
                        queue.append(new)
                changes.append((dep, ref))
            self.rewrite(f, changes)
        return done

    def rewrite(self, f: Path, changes):
        args = []
        for old, new in changes:
            if old == new:
                continue
            args += ["-change", old, new]
        # id
        if f.suffix == ".dylib" or ".framework/" in str(f):
            try:
                rel = os.path.relpath(f, self.fw)
            except ValueError:
                rel = f.name
            if not rel.startswith(".."):
                args += ["-id", "@rpath/" + rel]
            else:
                args += ["-id", "@rpath/" + f.name]
        rel = os.path.relpath(self.fw, f.parent)
        want = "@loader_path/" + rel if rel != "." else "@loader_path"
        have = rpaths_of(f)
        for rp in dict.fromkeys(have):
            if rp != want:
                args += ["-delete_rpath", rp]
        if want not in have:
            args += ["-add_rpath", want]
        run("install_name_tool", *args, f)


def copy_tree(src, dst, **kw):
    # Homebrew's share/qt tree is made of symlinks into the Cellar: dereference them
    shutil.copytree(src, dst, symlinks=False, dirs_exist_ok=True, **kw)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", required=True, help="DESTDIR of meson install")
    ap.add_argument("--prefix", default="/opt/vlc-redesign", help="meson --prefix used for the staging")
    ap.add_argument("--out", required=True, help="output directory (app is created inside)")
    ap.add_argument("--version", default="4.0.0-dev")
    ap.add_argument("--suffix", default="r1", help="fork build suffix")
    ap.add_argument("--qml-root", default=str(REPO / "modules/gui/qt"))
    a = ap.parse_args()

    stage = Path(a.stage) / a.prefix.lstrip("/")
    out = Path(a.out)
    app = out / APP_NAME
    if app.exists():
        shutil.rmtree(app)
    c = app / "Contents"
    for d in ("MacOS", "Frameworks", "PlugIns", "Resources"):
        (c / d).mkdir(parents=True)

    # --- VLC proper
    shutil.copy2(stage / "bin/vlc", c / "MacOS/VLC")
    for h in (stage / "libexec/vlc").iterdir():
        shutil.copy2(h, c / "MacOS" / h.name)  # vlc-cache-gen is removed again after use
    for l in stage.glob("lib/libvlc*.dylib"):
        if not l.is_symlink():
            shutil.copy2(l, c / "Frameworks" / l.name)
    # plugins: copy the module categories, drop the (stale) plugins.dat
    pdst = c / "Frameworks/plugins"
    # dbus plugins always fail on macOS (no session bus) before iokit_inhibit gets a chance: leave them out
    copy_tree(stage / "lib/vlc/plugins", pdst,
              ignore=shutil.ignore_patterns("plugins.dat", "libdbus*_plugin.dylib"))

    # --- Qt plugins
    for cat, names in QT_PLUGINS.items():
        for n in names:
            src = QT_ROOT / "plugins" / cat / n
            if src.exists():
                (c / "PlugIns" / cat).mkdir(exist_ok=True)
                shutil.copy2(os.path.realpath(src), c / "PlugIns" / cat / n)
            elif cat in ("platforms",):
                sys.exit(f"missing required Qt plugin {src}")

    # --- Qt QML imports actually used by modules/gui/qt
    # Modules imported by modules/gui/qt (see `grep -rh ^import modules/gui/qt`) plus what Qt Quick Controls needs
    # to resolve its default (macOS native) style. Everything else qmlimportscanner reports for QtQuick
    # (Scene3D, Pdf, VirtualKeyboard, Timeline, other Controls styles ...) is not used and is left out.
    scan = json.loads(run(QT_ROOT / "libexec/qmlimportscanner", "-rootPath", a.qml_root,
                          "-importPath", QT_ROOT / "qml"))
    found = {Path(e["path"]) for e in scan if e.get("type") == "module" and e.get("path")}
    qroot = QT_ROOT / "qml"
    wanted = ["QML", "QtQml", "QtQml/Models", "QtQml/WorkerScript", "QtQuick", "QtQuick/Window",
              "QtQuick/Layouts", "QtQuick/Shapes", "QtQuick/Templates", "QtQuick/Effects",
              "QtQuick/Controls", "QtQuick/Controls/impl", "QtQuick/Controls/Basic",
              "QtQuick/Controls/Basic/impl", "QtQuick/Controls/macOS", "QtQuick/Controls/macOS/impl",
              "QtQuick/NativeStyle"]
    mods = [qroot / w for w in wanted if (qroot / w) in found or (qroot / w).is_dir()]
    selected = set(mods)
    for m in mods:
        def ign(d, names, _sel=selected):
            r = []
            for n in names:
                p = Path(d) / n
                if p.is_dir() and ((p / "qmldir").exists() and p not in _sel
                                                           or n in ("designer", "Headers")):
                    r.append(n)
                if n.endswith((".qmltypes", ".dSYM")):
                    r.append(n)
            return r
        copy_tree(m, c / "Resources/qml" / m.relative_to(qroot), ignore=ign)

    # --- resources
    shutil.copy2(REPO / "extras/package/macosx/asset_sources/redesign/VLC.icns", c / "Resources/VLC.icns")
    (c / "Resources/share").mkdir()
    (c / "Resources/qt.conf").write_text("[Paths]\nPlugins = PlugIns\nQml2Imports = Resources/qml\nImports = Resources/qml\n")
    run(sys.executable, HERE / "make_infoplist.py", REPO / "share/Info.plist.in", c / "Info.plist",
        a.version, a.suffix)
    (c / "PkgInfo").write_text("APPL????")

    # --- relocate every Mach-O
    b = Bundler(app)
    b.extra_search = [str(stage / "lib")]
    b.relocate()

    # LSMinimumSystemVersion must be truthful: dyld refuses images built for a newer macOS than the one
    # running. Bundled Homebrew bottles carry the minos of the macOS they were built on (14 on a macos-14
    # runner, 15 on macos-15, 26 on a Tahoe host), so take the maximum over every Mach-O.
    minos = max_minos(c)
    info = plistlib.loads((c / "Info.plist").read_bytes())
    floor = max(14.0, minos)
    info["LSMinimumSystemVersion"] = f"{floor:.1f}"
    (c / "Info.plist").write_bytes(plistlib.dumps(info))
    print(f"max minos over all Mach-O files: {minos:.1f} -> LSMinimumSystemVersion {info['LSMinimumSystemVersion']}")
    sign_code(app)  # relocated binaries are killed by the kernel unless (ad-hoc) re-signed
    # --- plugin cache (must run on the relocated plugins, from the final location)
    env = {"PATH": "/usr/bin:/bin", "VLC_PLUGIN_PATH": str(pdst), "VLC_LIB_PATH": str(c / "Frameworks")}
    subprocess.run([str(c / "MacOS/vlc-cache-gen"), str(pdst)], check=True, env=env,
                   stdout=subprocess.DEVNULL)
    (c / "MacOS/vlc-cache-gen").unlink()  # build-time tool, not shipped
    assert (pdst / "plugins.dat").exists(), "plugins.dat not generated"

    # Anything in Contents/Frameworks is considered nested code by codesign, including plugins.dat:
    # sign it too (signature is kept in extended attributes; use ditto/hdiutil, not cp/zip, to copy).
    run("codesign", "--force", "--sign", "-", "--timestamp=none", pdst / "plugins.dat")
    run("codesign", "--force", "--sign", "-", "--timestamp=none", app)
    print(app)


def max_minos(root: Path):
    best = 0.0
    for p in macho_files(root):
        out = run("otool", "-l", p).splitlines()
        for i, l in enumerate(out):
            m = re.match(r"\s*minos (\d+)(?:\.(\d+))?", l)
            if m:
                best = max(best, float(f"{m.group(1)}.{m.group(2) or 0}"))
    return best


def sign_code(app: Path):
    c = app / "Contents"
    fws = sorted(c.glob("Frameworks/*.framework"))
    inside_fw = lambda p: any(str(p).startswith(str(f) + "/") for f in fws)
    files = [p for p in macho_files(c) if not inside_fw(p)]
    # deepest first
    files.sort(key=lambda p: -len(p.parts))
    for p in files:
        run("codesign", "--force", "--sign", "-", "--timestamp=none", p)
    for f in fws:
        run("codesign", "--force", "--sign", "-", "--timestamp=none", f)


if __name__ == "__main__":
    main()
