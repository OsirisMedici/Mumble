"""Gate publication of already-verified native build artifacts."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', path], text=True))


repository = os.environ['GITHUB_REPOSITORY']
source = os.environ['SOURCE_REVISION']
assert re.fullmatch(r'[0-9a-f]{40}', source)
source_tree = api(f'repos/{repository}/git/commits/{source}')['tree']['sha']
for variable, workflow in [('MAC_RUN', 'Desktop preview release'), ('WINDOWS_RUN', 'Windows preview')]:
    run_id = os.environ[variable]
    assert run_id.isdigit()
    run = api(f'repos/{repository}/actions/runs/{run_id}')
    assert run['status'] == 'completed' and run['conclusion'] == 'success', run
    assert run['head_sha'] == source and run['name'] == workflow, run
    assert run['repository']['full_name'] == repository

assets = Path('release-assets')
targets = ['aarch64-apple-darwin', 'x86_64-apple-darwin']
expected = {'LICENSE', 'THIRD_PARTY_NOTICES.md', 'Mumble_0.1.0_windows_x64-setup.exe',
            'Mumble_0.1.0_windows_x64_portable.zip', 'Windows-verification.json', 'SHA256SUMS-windows-x64.txt'}
for target in targets:
    expected.update({f'Mumble_0.1.0_{target}.dmg', f'Mumble_0.1.0_{target}.app.zip',
                     f'Mac-verification-{target}.json', f'SHA256SUMS-{target}.txt'})
assert {p.name for p in assets.iterdir()} == expected, list(assets.iterdir())
covered = set()
for manifest in assets.glob('SHA256SUMS-*.txt'):
    for line in manifest.read_text(encoding='utf-8-sig').splitlines():
        digest, name = line.split(None, 1)
        assert name in expected and '/' not in name and '\\' not in name
        assert re.fullmatch(r'[a-f0-9]{64}', digest)
        assert hashlib.sha256((assets / name).read_bytes()).hexdigest() == digest, name
        covered.add(name)
assert expected - {p.name for p in assets.glob('SHA256SUMS-*.txt')} == covered
for target in targets:
    report = json.loads((assets / f'Mac-verification-{target}.json').read_text())
    assert report['source_revision'] == source and report['target'] == target
    assert report['strict_signature'] == report['native_startup'] == 'passed'
    assert '25 chairs' in report['speech']['text'].lower()
    assert 'alex@example.com' in report['speech']['text'].lower()
report = json.loads((assets / 'Windows-verification.json').read_text(encoding='utf-8-sig'))
# A pull_request run records its synthetic merge commit. Verify the actual tree.
assert api(f"repos/{repository}/git/commits/{report['source_revision']}")['tree']['sha'] == source_tree
assert report['normal_install'] == report['portable_install'] == report['native_startup'] == 'passed'
assert '25 chairs' in report['generated_speech'].lower()
assert 'john@gmail.com' in report['generated_speech'].lower()
print(f'Validated all {len(expected)} assets against successful builds of {source}.')
