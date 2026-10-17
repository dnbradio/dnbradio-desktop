#!/usr/bin/env python3
"""Regenerate branded launcher assets from menu-bar.svg (the supplied DNBRADIO logo).

Requires ImageMagick. On macOS, also builds the bundled .icns using iconutil.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

packaging = Path(__file__).resolve().parents[1] / "packaging"
ET.register_namespace("", "http://www.w3.org/2000/svg")
source = ET.parse(packaging / "menu-bar.svg").getroot()
svg = ET.Element("svg", xmlns="http://www.w3.org/2000/svg", width="128", height="128", viewBox="0 0 128 128")
ET.SubElement(svg, "rect", width="128", height="128", rx="26", fill="#171920")
logo = ET.SubElement(svg, "g", fill="#e8ac76", transform="translate(8 8) scale(3.5)")
for path in source.findall("{http://www.w3.org/2000/svg}path"):
    ET.SubElement(logo, "path", d=path.attrib["d"])
app_svg = packaging / "com.dnbradio.Player.svg"
app_svg.write_bytes(ET.tostring(svg) + b"\n")
if sys.platform == "darwin":
    magick = shutil.which("magick")
    if not magick:
        raise SystemExit("ImageMagick is needed to regenerate the macOS icon")
    with tempfile.TemporaryDirectory(prefix="dnbradio-icons-") as temp:
        iconset = Path(temp) / "dnbradio.iconset"
        iconset.mkdir()
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                pixels = size * scale
                inset = round(pixels * 0.82)
                suffix = "@2x" if scale == 2 else ""
                subprocess.run([magick, "-background", "none", "-density", "768", str(app_svg),
                                "-resize", f"{inset}x{inset}", "-gravity", "center", "-extent", f"{pixels}x{pixels}",
                                str(iconset / f"icon_{size}x{size}{suffix}.png")], check=True)
        subprocess.run(["iconutil", "--convert", "icns", "--output", str(packaging / "dnbradio.icns"), str(iconset)], check=True)
print("Generated launcher icon" + (" and macOS .icns" if sys.platform == "darwin" else ""))
