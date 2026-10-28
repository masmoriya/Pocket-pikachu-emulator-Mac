#!/usr/bin/env python3
"""Compile and exercise the actual shared snapshot model without the Watch runtime."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="pikachu-snapshot-") as directory:
    executable = str(Path(directory) / "snapshot-tests")
    subprocess.run([
        "xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
        str(root / "Shared/PetSnapshot.swift"),
        str(root / "tools/test-snapshot.swift"), "-o", executable,
    ], check=True)
    subprocess.run([executable], check=True)
