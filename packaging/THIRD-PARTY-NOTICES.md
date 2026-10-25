# Bundled Windows runtime components

DNBRADIO is free software under the GNU General Public License, version 3 or
later. See `LICENSE.txt`. The source code is at
https://github.com/dnbradio/dnbradio-os-player.

DNBRADIO dynamically links Qt and FFmpeg. These components retain their own
copyrights and licenses. You may replace the shared libraries with compatible
versions. DNBRADIO's license does not restrict rights granted by the third-party
licenses, including debugging modifications to those libraries. License texts
are included under `licenses/`.

- Qt: Copyright The Qt Company Ltd. and contributors. Qt libraries are used
  under LGPL v3, with applicable third-party notices and exceptions. The exact
  Qt version is recorded in `BUILD-INFO.json`. Source and component notices:
  https://download.qt.io/archive/qt/ and https://code.qt.io/cgit/qt/
- FFmpeg: Copyright FFmpeg contributors. The Qt-supplied FFmpeg shared libraries
  are used under LGPL v2.1 or later. Source and build information:
  https://ffmpeg.org/download.html and https://doc.qt.io/qt-6.10/qtmultimedia-index.html
- Microsoft Visual C++ runtime: Copyright Microsoft Corporation. Unmodified
  redistributable x64 DLLs are included from the Visual Studio redist directory.
  https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files

Qt deployment also includes graphics support libraries and Qt's third-party
components. Their notices and sources are included in the corresponding Qt
source distribution. This build does not modify Qt or FFmpeg.
