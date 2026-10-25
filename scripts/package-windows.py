#!/usr/bin/env python3
"""Package MSVC x64 release and QA builds with Qt and app-local runtime DLLs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request

root = Path(__file__).resolve().parents[1]


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def deploy(executable, destination, qml_directories, runtime):
    destination.mkdir(parents=True, exist_ok=False)
    shutil.copy2(executable, destination / "dnbradio.exe")
    for qml in qml_directories:
        subprocess.run(["windeployqt", "--release", "--qmldir", str(qml),
                        "--dir", str(destination), "--no-compiler-runtime", "--no-translations",
                        "--include-plugins", "qsvg,qsvgicon,qjpeg,qwebp",
                        "--skip-plugin-types", "qmltooling,generic", str(destination / "dnbradio.exe")], check=True)
    for dll in runtime.glob("*.dll"):
        shutil.copy2(dll, destination)
    # Keep plugin and QML discovery relative to the extracted application.
    (destination / "qt.conf").write_text("[Paths]\nPrefix=.\nPlugins=.\nQmlImports=qml\n", encoding="utf-8")
    for required in ("Qt6Core.dll", "Qt6Quick.dll", "Qt6Multimedia.dll", "platforms/qwindows.dll",
                     "tls/qschannelbackend.dll", "imageformats/qsvg.dll", "iconengines/qsvgicon.dll",
                     "multimedia/ffmpegmediaplugin.dll", "vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll"):
        if not (destination / required).is_file():
            raise RuntimeError(f"Missing deployed dependency: {required}")
    if not list(destination.glob("avcodec-*.dll")):
        raise RuntimeError("FFmpeg codec libraries were not deployed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("test_executable", type=Path)
    parser.add_argument("--output", type=Path, default=root / "dist")
    args = parser.parse_args()
    if sys.platform != "win32":
        parser.error("Run on Windows with MSVC and Qt on PATH")
    version = re.search(r"project\(Dnbradio VERSION ([\d.]+)", (root / "CMakeLists.txt").read_text())[1]
    source = run("git", "-C", str(root), "rev-parse", "HEAD")
    qt_version = run("qtpaths", "--qt-version")
    vswhere = Path(os.environ["ProgramFiles(x86)"]) / "Microsoft Visual Studio/Installer/vswhere.exe"
    visual_studio = Path(run(str(vswhere), "-latest", "-products", "*", "-requires",
                             "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"))
    runtimes = [p for p in (visual_studio / "VC/Redist/MSVC").glob("*/x64/Microsoft.VC143.CRT")
                if re.fullmatch(r"\d+(?:\.\d+)+", p.parents[1].name)]
    if not runtimes:
        raise RuntimeError("Visual Studio x64 redistributable DLLs were not found")
    runtime = max(runtimes, key=lambda p: tuple(int(n) for n in p.parents[1].name.split(".")))
    args.output.mkdir(parents=True, exist_ok=True)
    stage = root / "build-windows-package/DNBRADIO"
    qa = root / "build-windows-package/QA"
    deploy(args.executable.resolve(), stage, [root / "qml"], runtime)
    deploy(args.test_executable.resolve(), qa, [root / "qml", root / "tests"], runtime)
    if any(stage.rglob("*Test*.dll")) or (stage / "qml/QtTest").exists():
        raise RuntimeError("Test libraries must not be included in the release")
    shutil.copy2(root / "packaging/windows-README.txt", stage / "README.txt")
    shutil.copy2(root / "packaging/THIRD-PARTY-NOTICES.md", stage)
    shutil.copy2(root / "LICENSE", stage / "LICENSE.txt")
    licenses = stage / "licenses"
    licenses.mkdir()
    for name in ("LGPL-3.0-only", "GPL-3.0-only", "GPL-2.0-only", "Qt-GPL-exception-1.0"):
        url = f"https://raw.githubusercontent.com/qt/qtbase/v{qt_version}/LICENSES/{name}.txt"
        with urllib.request.urlopen(url, timeout=30) as response:
            (licenses / f"{name}.txt").write_bytes(response.read())
    with urllib.request.urlopen("https://raw.githubusercontent.com/FFmpeg/FFmpeg/n7.1.1/COPYING.LGPLv2.1", timeout=30) as response:
        (licenses / "FFmpeg-LGPL-2.1.txt").write_bytes(response.read())
    (stage / "BUILD-INFO.json").write_text(json.dumps({
        "version": version, "source_commit": source, "qt_version": qt_version,
        "architecture": "x86_64", "build_testing": False,
        "compiler_runtime": runtime.parents[1].name, "signing": "unsigned",
    }, indent=2) + "\n", encoding="utf-8")
    archive = Path(shutil.make_archive(str(args.output / f"dnbradio-{version}-windows-x86_64"),
                                      "zip", stage.parent, stage.name))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (args.output / "SHA256SUMS-windows").write_bytes(f"{digest}  {archive.name}\n".encode("ascii"))
    print(f"Packaged {archive} (SHA-256 {digest}); QA bundle: {qa}")


if __name__ == "__main__":
    main()
