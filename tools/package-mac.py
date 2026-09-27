#!/usr/bin/env python3
"""Build a universal local app. Distribution signing/notarization is opt-in."""
import argparse
import fcntl
import pathlib
import plistlib
import shutil
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--identity', default='-', help='Developer ID Application identity; default is local ad-hoc signing')
parser.add_argument('--notary-profile', help='Existing notarytool Keychain profile; requires --identity')
args = parser.parse_args()
lock_path = root / 'mac/.build/.packaging.lock'
lock_path.parent.mkdir(parents=True, exist_ok=True)
package_lock = lock_path.open('w')
fcntl.flock(package_lock, fcntl.LOCK_EX)
if args.notary_profile and args.identity == '-':
    parser.error('Notarization requires a Developer ID Application identity.')

def run(*argv):
    subprocess.run(list(map(str, argv)), cwd=root, check=True)

run('node', root / 'tools/extract-animations.mjs')
run('node', root / 'tools/build-atlases.mjs')
run('node', root / 'tools/validate-assets.mjs')
for arch in ('arm64', 'x86_64'):
    run('swift', 'build', '--package-path', root / 'mac', '-c', 'release', '--arch', arch)
app = root / 'dist/Pocket Pikachu.app'
if app.exists():
    shutil.rmtree(app)  # Only this script's generated app bundle.
contents = app / 'Contents'
(contents / 'MacOS').mkdir(parents=True)
(contents / 'Resources').mkdir()
run('lipo', '-create', root / 'mac/.build/arm64-apple-macosx/release/PocketPikachu',
    root / 'mac/.build/x86_64-apple-macosx/release/PocketPikachu', '-output', contents / 'MacOS/PocketPikachu')
# Use the affectionate sprite icon generated from the original animation atlas.
with tempfile.TemporaryDirectory(prefix='pocket-pikachu-icon-') as temporary:
    iconset = pathlib.Path(temporary) / 'AppIcon.iconset'
    iconset.mkdir()
    source = root / 'art/app-icon.png'
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = size * scale
            filename = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
            run('sips', '-z', pixels, pixels, source, '--out', iconset / filename)
    run('iconutil', '-c', 'icns', iconset, '-o', contents / 'Resources/AppIcon.icns')
# AppResources resolves the signed app resource bundle before falling back to SwiftPM.
shutil.copytree(root / 'mac/.build/arm64-apple-macosx/release/PocketPikachu_PocketPikachu.bundle',
                contents / 'Resources/PocketPikachu_PocketPikachu.bundle')
with (contents / 'Info.plist').open('wb') as stream:
    plistlib.dump(dict(CFBundleIdentifier='life.pokpik.companion', CFBundleName='Pocket Pikachu',
        CFBundleDisplayName='Pocket Pikachu', CFBundleExecutable='PocketPikachu',
        CFBundlePackageType='APPL', CFBundleShortVersionString='0.1.0', CFBundleVersion='1',
        LSMinimumSystemVersion='14.0', LSUIElement=True, NSHighResolutionCapable=True,
        CFBundleIconFile='AppIcon.icns'), stream)
command = ['codesign', '--force', '--deep', '--sign', args.identity]
if args.identity != '-':
    command += ['--options', 'runtime', '--timestamp']
run(*command, app)
run('codesign', '--verify', '--deep', '--strict', app)
archive = root / 'dist/PocketPikachu.zip'
run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app, archive)
if args.notary_profile:
    run('xcrun', 'notarytool', 'submit', archive, '--keychain-profile', args.notary_profile, '--wait')
    run('xcrun', 'stapler', 'staple', app)
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app, archive)
print('Built dist/Pocket Pikachu.app and dist/PocketPikachu.zip')
