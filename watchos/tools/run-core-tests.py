#!/usr/bin/env python3
"""Run actual WatchCore XCTest sources when SwiftPM SDK cache planning stalls.

Uses the active Xcode compiler directly, no production substitutions or fixtures.
SwiftPM remains the normal test entry point; this is a focused host fallback.
"""
from pathlib import Path
import re
import subprocess
import tempfile
import platform
import sys


def main():
    root = Path(__file__).resolve().parents[1]
    developer = subprocess.check_output(['xcode-select', '-p'], text=True).strip()
    compiler = str(Path(developer) / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc')
    sdk = str(Path(developer) / 'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk')
    frameworks = str(Path(developer) / 'Platforms/MacOSX.platform/Developer/Library/Frameworks')
    test_libraries = str(Path(developer) / 'Platforms/MacOSX.platform/Developer/usr/lib')
    sources = sorted(str(path.relative_to(root)) for path in (root / 'Sources/WatchCore').glob('*.swift'))
    tests = sorted((root / 'Tests/WatchCoreTests').glob('*.swift'))
    cases = []
    count = 0
    for path in tests:
        source = path.read_text()
        name = re.search(r'final class (\w+): XCTestCase', source)
        methods = re.findall(r'\bfunc (test\w+)\(', source)
        if not name or not methods:
            raise RuntimeError(f'Cannot discover XCTest methods in {path.name}')
        cases.append(f'suite.addTest({name[1]}.defaultTestSuite)')
        count += len(methods)
    with tempfile.TemporaryDirectory(prefix='watch-core-tests-') as directory:
        output = Path(directory)
        runner = output / 'main.swift'
        # Darwin XCTest uses runtime suites rather than Linux's XCTMain entry point.
        runner.write_text('import XCTest\nimport Foundation\n'
                          'let suite = XCTestSuite(name: "WatchCore")\n' + '\n'.join(cases) +
                          '\nsuite.run()\n'
                          f'guard let run = suite.testRun, run.executionCount == {count}, run.hasSucceeded '
                          'else { exit(1) }\n')
        common = [compiler, '-swift-version', '6', '-sdk', sdk,
                  '-target', f'{platform.machine()}-apple-macosx14.0']
        subprocess.run(common + ['-emit-library', '-emit-module', '-enable-testing', '-module-name',
                                 'WatchCore', *sources, '-o', str(output / 'libWatchCore.dylib'),
                                 '-emit-module-path', str(output / 'WatchCore.swiftmodule')], cwd=root, check=True)
        executable = output / 'WatchCoreTests'
        subprocess.run(common + ['-I', directory, '-I', test_libraries,
                                 '-L', directory, '-L', test_libraries,
                                 '-lWatchCore', '-lXCTestSwiftSupport', '-F', frameworks,
                                 '-Xlinker', '-rpath', '-Xlinker', directory,
                                 '-Xlinker', '-rpath', '-Xlinker', frameworks,
                                 '-Xlinker', '-rpath', '-Xlinker', test_libraries,
                                 *[str(path.relative_to(root)) for path in tests], str(runner),
                                 '-o', str(executable)], cwd=root, check=True)
        print(f'Running {count} actual XCTest methods through the direct compiler fallback.', flush=True)
        subprocess.run([str(executable)], cwd=root, check=True)


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(f'Compiler or XCTest command exited with status {error.returncode}.', file=sys.stderr)
        sys.exit(error.returncode)
