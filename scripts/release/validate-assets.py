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
# Artifacts keep their exact source revision in their reports. Permit only
# documentation, install-helper and release-verification differences between
# platform builds; every other tracked blob must be identical to the release tag.
def application_tree(revision):
    tree = api(f'repos/{repository}/git/trees/{revision}?recursive=1')
    assert not tree.get('truncated'), 'Cannot verify a truncated source tree'
    ignored_files = {'README.md', 'BUILD.md', '.github/workflows/install-smoke.yml',
                     '.github/workflows/publish-verified.yml', '.github/workflows/release.yml',
                     'scripts/ci/package-macos.py'}
    ignored_prefixes = ('docs/', 'scripts/install/', 'scripts/release/')
    return {item['path']: (item['mode'], item['sha']) for item in tree['tree']
            if item['type'] != 'tree' and item['path'] not in ignored_files
            and not item['path'].startswith(ignored_prefixes)}

release_tree = application_tree(source)
run_heads = {}
for variable, workflow in [('MAC_RUN', 'Desktop preview release'), ('WINDOWS_RUN', 'Windows preview')]:
    run_id = os.environ[variable]
    assert run_id.isdigit()
    run = api(f'repos/{repository}/actions/runs/{run_id}')
    assert run['status'] == 'completed' and run['conclusion'] == 'success', run
    assert run['name'] == workflow and run['repository']['full_name'] == repository, run
    assert application_tree(run['head_sha']) == release_tree, 'Application source differs between builds'
    run_heads[variable] = run['head_sha']

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
    assert report['source_revision'] == run_heads['MAC_RUN'] and report['target'] == target
    assert report['strict_signature'] == report['native_startup'] == 'passed'
    assert '25 chairs' in report['speech']['text'].lower()
    assert 'alex@example.com' in report['speech']['text'].lower()
report = json.loads((assets / 'Windows-verification.json').read_text(encoding='utf-8-sig'))
# A pull_request run records its synthetic merge commit. Verify the actual tree.
assert api(f"repos/{repository}/git/commits/{report['source_revision']}")['tree']['sha'] == api(f"repos/{repository}/git/commits/{run_heads['WINDOWS_RUN']}")['tree']['sha']
assert report['normal_install'] == report['portable_install'] == report['native_startup'] == 'passed'
assert '25 chairs' in report['generated_speech'].lower()
assert 'john@gmail.com' in report['generated_speech'].lower()
print(f'Validated all {len(expected)} assets. Application source matches release {source}; exact build revisions are preserved in the reports.')
