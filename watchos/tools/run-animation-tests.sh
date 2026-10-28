#!/bin/sh
# Compile the production Foundation playback code without Xcode or SwiftUI.
set -eu
python3 - "$0" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile

watchos = Path(sys.argv[1]).resolve().parents[1]
source = watchos / 'PocketPikachuWatch/Animation'
with tempfile.TemporaryDirectory(prefix='pikachu-animation-tests-') as temporary:
    binary = Path(temporary) / 'animation-tests'
    subprocess.run([
        'swiftc', '-parse-as-library',
        str(source / 'AnimationLibrary.swift'), str(source / 'AnimationEngine.swift'),
        str(watchos / 'tools/test-animation.swift'), '-o', str(binary)
    ], check=True)
    subprocess.run([
        str(binary), str(watchos / 'PocketPikachuWatch/Resources/animations.json')
    ], check=True)
PY
