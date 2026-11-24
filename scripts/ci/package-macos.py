"""Verify a built Mac app and create plain, scriptable release archives."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
import urllib.request


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


if os.environ.get('GITHUB_ACTIONS') != 'true':
    raise SystemExit('This helper writes temporary CI app settings; run it on a disposable GitHub runner.')
target = sys.argv[1]
assert target in ('aarch64-apple-darwin', 'x86_64-apple-darwin')
repo = Path.cwd()
app = repo / f'src-tauri/target/{target}/release/bundle/macos/Mumble.app'
exe = app / 'Contents/MacOS/karen-voice'
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.osirismedici.karenvoice'
assert info['CFBundleName'] == 'Mumble'
version = info['CFBundleShortVersionString']
run('codesign', '--verify', '--deep', '--strict', str(app))
for name in ('LICENSE', 'THIRD_PARTY_NOTICES.md'):
    assert (app / 'Contents/Resources/resources/licenses' / name).is_file()
# A framework must not remain linked to the temporary build directory.
for binary in [exe, *(app / 'Contents/Frameworks').glob('*.dylib')]:
    linked = subprocess.check_output(['otool', '-L', str(binary)], text=True)
    for line in linked.splitlines()[1:]:
        dependency = line.strip().split(' (', 1)[0]
        assert not (dependency.startswith('/Users/') or dependency.startswith('/private/')), linked
run(str(exe), '--list-devices', timeout=90)

# Synthetic speech verifies the installed bundle's actual engine on each CPU arch.
data = Path.home() / 'Library/Application Support/com.osirismedici.karenvoice'
models = data / 'models'
models.mkdir(parents=True, exist_ok=True)
model = models / 'parakeet-tdt-0.6b-v3-Q8_0.gguf'
url = 'https://blob.handy.computer/handy-computer/parakeet-tdt-0.6b-v3-gguf/85ac09ea12fc4b1112fa76810059364bc6adc9de/parakeet-tdt-0.6b-v3-Q8_0.gguf'
if not model.exists():
    with urllib.request.urlopen(url, timeout=900) as response, model.open('wb') as output:
        while block := response.read(1024 * 1024):
            output.write(block)
assert hashlib.sha256(model.read_bytes()).hexdigest() == '5859f77944efcd8eafa23a6350731960b2b55b2203df51f319665c807d802cc7'
settings = data / 'settings_store.json'
store = json.loads(settings.read_text()) if settings.exists() else {}
store.setdefault('settings', {}).update(number_formatting_enabled=True, email_formatting_enabled=True)
settings.write_text(json.dumps(store))
with tempfile.TemporaryDirectory(prefix='mumble-package-') as temp:
    temp = Path(temp)
    audio = temp / 'sample.wav'
    run('say', '-v', 'Samantha', '-r', '155', '-o', str(audio), '--file-format=WAVE', '--data-format=LEI16@16000', '--channels=1',
        'This is a local transcription test. I need twenty five chairs. My email is alex at the rate example dot com.')
    run('python3', 'scripts/verify-built-transcription.py', str(exe), str(audio))
    result = json.loads(Path('transcription-result.json').read_text())
    assert '25 chairs' in result['text'].lower(), result
    assert 'alex@example.com' in result['text'].lower(), result
    # A plain read-only DMG avoids Finder/AppleScript layout automation on CI.
    stage = temp / 'dmg'
    stage.mkdir()
    run('ditto', str(app), str(stage / 'Mumble.app'))
    (stage / 'Applications').symlink_to('/Applications')
    assets = repo / 'release-assets'
    assets.mkdir(exist_ok=True)
    run('hdiutil', 'create', '-volname', 'Mumble', '-srcfolder', str(stage), '-ov', '-format', 'UDZO', str(assets / f'Mumble_{version}_{target}.dmg'))
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(assets / f'Mumble_{version}_{target}.app.zip'))
    for name in ('LICENSE', 'THIRD_PARTY_NOTICES.md'):
        (assets / name).write_bytes((repo / name).read_bytes())
    verification = {'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'target': target,
                    'strict_signature': 'passed', 'native_startup': 'passed', 'speech': result,
                    'binary_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(), 'notarized': False,
                    'microphone_shortcut_paste': 'interactive acceptance remains separate'}
    (assets / f'Mac-verification-{target}.json').write_text(json.dumps(verification, indent=2) + '\n')
    sums = [f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}' for p in sorted(assets.iterdir()) if p.is_file() and (target in p.name or p.name in ('LICENSE', 'THIRD_PARTY_NOTICES.md'))]
    (assets / f'SHA256SUMS-{target}.txt').write_text('\n'.join(sums) + '\n')
print(f'Verified and packaged Mumble for {target}.')
