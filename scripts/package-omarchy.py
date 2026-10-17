#!/usr/bin/env python3
"""Assemble the optional Omarchy plugin using the shared data and scrolling code."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path, help="New destination directory")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
if args.output.exists():
    parser.error("Destination already exists; choose a new directory.")
shutil.copytree(root / "integrations/omarchy", args.output)
for name in ["Data.js", "Stations.js", "SmoothScrollView.qml"]:
    shutil.copy2(root / "qml" / name, args.output / name)
print(args.output.resolve())
