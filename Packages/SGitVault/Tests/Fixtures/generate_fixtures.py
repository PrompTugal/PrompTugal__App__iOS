#!/usr/bin/env python3
"""Generate THROWAWAY sgit test vaults for the SGitVault Swift tests.

Every key written here is a throwaway created for these tests. None of these
vaults exists on any server, and none holds anything but the text below.

It drives sgit-ai's own Vault__Sync (pip install sgit-ai==0.27.0) against
sgit's in-memory server (Vault__API__In_Memory), so the files written to
<fixture>/server/ are exactly what https://dev.send.sgraph.ai would hold
under /api/vault/read/<vault_id>/<path>.

Usage:  python3 -I generate_fixtures.py <output-dir>
Writes: <output-dir>/<name>/server/bare/...    the ciphertext, as the server holds it
        <output-dir>/<name>/expected.json      throwaway keys + expected plaintext
"""
import hashlib
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from sgit_ai.core.Vault__Sync import Vault__Sync
from sgit_ai.core.actions.branch.Vault__Branch_Switch import Vault__Branch_Switch
from sgit_ai.crypto.Vault__Crypto import Vault__Crypto
from sgit_ai.network.api.Vault__API__In_Memory import Vault__API__In_Memory

BIG = 'PrompTugal fixture line, repeated so deflate shrinks it.\n' * 200


def write(root: Path, rel: str, text: str):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


def dump_server(api, vault_id: str, out: Path):
    prefix = f'{vault_id}/'
    n = 0
    for key, data in sorted(api._store.items()):
        if not key.startswith(prefix):
            continue
        rel = key[len(prefix):]
        dest = out / 'server' / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        n += 1
    return n


def files_of(work: Path):
    result = {}
    for p in sorted(work.rglob('*')):
        if p.is_file() and '.sg_vault' not in p.parts:
            data = p.read_bytes()
            entry = {'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
            if len(data) <= 200:
                entry['text'] = data.decode()
            result[p.relative_to(work).as_posix()] = entry
    return result


def make(name: str, passphrase: str, vault_id: str, out_root: Path, deflate: bool):
    out = out_root / name
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    vault_key = f'{passphrase}:{vault_id}'
    api = Vault__API__In_Memory().setup()
    crypto = Vault__Crypto(deflate_blobs=deflate)
    sync = Vault__Sync(crypto=crypto, api=api)
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / 'work'
        sync.init(str(work), vault_key=vault_key)
        if deflate:                         # format 2: 32-hex object ids, blobs deflated before encryption
            sync.set_format(str(work), format=2, add_features=['blob-deflate'])
        # commit 1
        write(work, 'README.md', '# Fixture vault\n\nThrowaway test data for SGitVault. Not a secret.\n')
        write(work, 'picks.json', '{"v":1,"picks":[{"id":"events/demo","at":1762650000000}]}')
        sync.commit(str(work), message='Fixture commit one')
        sync.push(str(work))
        # commit 2: nested folders and a large, compressible file
        write(work, 'docs/big.txt', BIG)
        write(work, 'docs/deep/note.txt', 'deep file\n')
        write(work, 'notes/ünïcode name.md', 'Olá, Lisboa.\n')
        sync.commit(str(work), message='Fixture commit two: docs')
        sync.push(str(work))
        expected_main = files_of(work)
        # a second named branch with one extra file
        Vault__Branch_Switch(crypto=crypto).branch_new(str(work), 'device-ipad')
        write(work, 'device.txt', 'written on the ipad branch\n')
        sync.commit(str(work), message='Fixture commit on device-ipad')
        sync.push(str(work))
        expected_ipad = files_of(work)
        keys = crypto.derive_keys_from_vault_key(vault_key)
        n = dump_server(api, vault_id, out)
    expected = {
        'WARNING': 'THROWAWAY test keys for test fixtures only. These vaults exist on no server.',
        'generator': 'generate_fixtures.py with sgit-ai 0.27.0',
        'vault_id': vault_id,
        'vault_key': f'sgit_private_vault_{vault_key}',
        'read_key': f'sgit_private_read_{keys["read_key"]}:{vault_id}',
        'read_key_hex': keys['read_key'],
        'write_key_hex': keys['write_key'],
        'branch_index_file_id': keys['branch_index_file_id'],
        'ref_file_id': keys['ref_file_id'],
        'deflate': deflate,
        'objects_on_server': n,
        'branches': {
            'current': {'messages': ['Fixture commit two: docs', 'Fixture commit one', 'init'],
                        'files': expected_main},
            'device-ipad': {'messages': ['Fixture commit on device-ipad', 'Fixture commit two: docs',
                                         'Fixture commit one', 'init'],
                            'files': expected_ipad},
        },
    }
    (out / 'expected.json').write_text(json.dumps(expected, indent=1, ensure_ascii=False) + '\n')
    print(name, vault_id, n, 'server files')


def main():
    out_root = Path(sys.argv[1])
    make('plain', 'throwaway-fixture-plain', 'fixtplain1', out_root, deflate=False)
    make('deflate', 'throwaway-fixture-deflate', 'fixtdefl1', out_root, deflate=True)


if __name__ == '__main__':
    main()
