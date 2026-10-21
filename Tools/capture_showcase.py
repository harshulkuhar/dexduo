#!/usr/bin/env python3
"""Capture actual Simulator displays using a temporary XCTest project; writes no media into Git."""
import argparse
import json
import pathlib
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Booted Simulator UUID')
    parser.add_argument('--kind', choices=['iphone', 'duo'], required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--derived', type=pathlib.Path, required=True)
    args = parser.parse_args()
    repo = pathlib.Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output == repo or repo in output.parents:
        parser.error('Captures must be outside the repository.')
    output.mkdir(parents=True, exist_ok=True)
    fixture = repo / 'Tests/Fixtures/espeon.png'
    if not fixture.exists():
        parser.error('Restore ignored fixtures first with Tools/download_test_fixtures.py.')
    subprocess.run(['xcrun', 'simctl', 'addmedia', args.device, str(fixture)], check=True)
    with tempfile.TemporaryDirectory(prefix='DexDuoShowcase-') as temporary:
        root = pathlib.Path(temporary)
        for directory in ['DexDuo', 'Tests', 'Tools']:
            (root / directory).symlink_to(repo / directory, target_is_directory=True)
        project = root / 'DexDuo.xcodeproj'
        shutil.copytree(repo / 'DexDuo.xcodeproj', project)
        path = project / 'project.pbxproj'
        source = path.read_text()
        source = source.replace('objects = {', '''objects = {
AA2000000000000000000001 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "../Tools/CaptureShowcase.swift"; sourceTree = "<group>"; };
AA2000000000000000000002 = {isa = PBXBuildFile; fileRef = AA2000000000000000000001; };''', 1)
        source = re.sub(r'(isa = PBXGroup; children = \()(?=[^\n]*path = Tests;)', r'\g<1>AA2000000000000000000001, ', source)
        target = re.search(r'[^\n]*isa = PBXNativeTarget;[^\n]*name = DexDuoUITests;[^\n]*', source).group()
        phases = re.search(r'buildPhases = \(([^)]+)', target).group(1).split(',')
        phase = next(value.strip() for value in phases if re.search(value.strip() + r' = \{isa = PBXSourcesBuildPhase;', source))
        source = re.sub(r'(' + phase + r' = \{isa = PBXSourcesBuildPhase;[^\n]*files = \()', r'\g<1>AA2000000000000000000002, ', source)
        path.write_text(source)
        command = ['xcodebuild', 'test', '-project', str(project), '-scheme', 'DexDuo', '-destination', 'platform=iOS Simulator,id=' + args.device,
                   '-derivedDataPath', str(args.derived.resolve()), '-parallel-testing-enabled', 'NO', '-only-testing:DexDuoUITests/CaptureShowcase',
                   'CODE_SIGNING_ALLOWED=NO', 'ONLY_ACTIVE_ARCH=YES']
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        captured = set()
        with (output / 'capture.log').open('w') as log:
            for line in process.stdout:
                log.write(line); log.flush()
                match = re.fullmatch(r'DEXDUO_SHOWCASE:([a-z0-9-]+)\s*', line)
                if match:
                    name = match.group(1)
                    shot = ['xcrun', 'simctl', 'io', args.device, 'screenshot']
                    if args.kind == 'duo': shot += ['--display=3']
                    subprocess.run(shot + [str(output / (name + '.png'))], check=True)
                    captured.add(name); print('Captured ' + name, flush=True)
        status = process.wait()
        if status: raise SystemExit(f'XCTest failed ({status}); inspect {output / "capture.log"}')
        required = {'01-open', '02-recognition', '03-speech', '04-evolution', '05-matchup', '06-cover' if args.kind == 'iphone' else '06-interior'}
        if captured != required: raise SystemExit(f'Incomplete capture set: {captured}')
    (output / 'capture.json').write_text(json.dumps({'device':args.device,'kind':args.kind,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'scenes':sorted(captured),'recognition':'Actual classifier output from imported Espeon fixture; automatic lookup disabled for candidate visibility.','speech':'Capture waits for actual Speaking playback event.'},indent=2)+'\n')
    print('Six genuine scenes captured. For Duo, fold in Device Hub and capture display 1 as 06-cover.png before rendering.')


if __name__ == '__main__': main()
