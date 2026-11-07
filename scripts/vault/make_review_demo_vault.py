#!/usr/bin/env python3
"""Create a THROWAWAY demo vault for the App Reviewer (App Review readiness, item 7).

What it makes: a new sgit vault with a README and sample schedule picks
(three public sessions from https://promptugal.news/api/v1/live/agenda.json),
and nothing else: no team data, no keys of anyone on the team.

    pip install sgit-ai==0.27.0
    python3 -I scripts/vault/make_review_demo_vault.py --out /tmp/review-vault            # local only
    python3 -I scripts/vault/make_review_demo_vault.py --out /tmp/review-vault --token T  # and push it

- The vault's key is generated here and printed ONCE to this terminal. It is never
  written inside this repository (the script refuses an --out folder inside it).
  Paste the printed READ key into App Store Connect → App Review Information → Notes.
- Pushing needs a vault access token (--token, or the SGIT_TOKEN environment variable).
  Without one the vault stays in --out; push it later with `sgit push` from that folder.
- In the app the reviewer opens Vault, pastes the read key, taps Import. The vault opens
  read-only; picks and files show. Signatures are checked and pinned on first open.
- When review is over, delete the vault (`sgit vault delete-on-remote` from --out).
"""
import argparse
import json
import os
import secrets
import string
import subprocess
import sys
import urllib.request
from pathlib import Path

AGENDA = 'https://promptugal.news/api/v1/live/agenda.json'
ALPHABET = string.ascii_lowercase + string.digits


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def sample_picks(count: int = 3) -> dict:
    """Three public sessions, in the website's nr.schedule.v1 form."""
    try:
        with urllib.request.urlopen(AGENDA, timeout=20) as response:
            items = json.load(response).get('items', [])
    except Exception as error:                       # offline: placeholders the app shows as unknown events
        print(f'agenda not reachable ({error}); using placeholder ids', file=sys.stderr)
        items = []
    pages = [i['page'] for i in items if i.get('official') and i.get('page', '').endswith('/index.html')]
    ids = [p[:-len('/index.html')] for p in pages[:count]] or ['events/demo-session-1', 'events/demo-session-2']
    return {'v': 1, 'picks': [{'id': i, 'at': '2026-11-08T09:00:00.000Z'} for i in ids]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--out', required=True, help='a NEW folder outside this repository')
    parser.add_argument('--token', default=os.environ.get('SGIT_TOKEN'), help='vault access token, to push')
    args = parser.parse_args()

    out = Path(args.out).resolve()
    if out == repo_root() or repo_root() in out.parents:
        sys.exit('refusing: --out is inside the repository, and the vault key must never be committed')
    if out.exists() and any(out.iterdir()):
        sys.exit(f'refusing: {out} is not empty')
    out.mkdir(parents=True, exist_ok=True)

    passphrase = ''.join(secrets.choice(ALPHABET) for _ in range(24))
    vault_id = ''.join(secrets.choice(ALPHABET) for _ in range(8))
    vault_key = f'{passphrase}:{vault_id}'

    def sgit(*argv):
        global_args = ['--token', args.token] if args.token else []
        subprocess.run(['sgit', *global_args, *argv], cwd=out, check=True)

    sgit('init', '--vault-key', vault_key, '--existing', '.')
    (out / 'README.md').write_text(
        '# PrompTugal demo vault\n\n'
        'A throwaway vault made for App Review. It holds sample schedule picks and nothing else.\n')
    (out / 'apps' / 'agenda').mkdir(parents=True, exist_ok=True)
    (out / 'apps' / 'agenda' / 'picks.json').write_text(json.dumps(sample_picks(), separators=(',', ':')))
    sgit('commit', '-m', 'Demo vault for App Review: README and sample picks')
    if args.token:
        sgit('push')
    else:
        print('\nNot pushed (no --token). From that folder, run: sgit push --token <token>', file=sys.stderr)

    from sgit_ai.crypto.Vault__Crypto import Vault__Crypto
    read_hex = Vault__Crypto().derive_keys(passphrase, vault_id)['read_key']
    print('\nTHROWAWAY demo vault. Do not commit these; give the reviewer the READ key only.')
    print(f'  read key  (for App Review notes): sgit_private_read_{read_hex}:{vault_id}')
    print(f'  vault key (keep, to delete it later): sgit_private_vault_{vault_key}')
    print(f'  folder: {out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
