#!/usr/bin/env python3
"""Evidence for brief 04: an sgit vault can be read with nothing but the
primitives Apple CryptoKit provides (HMAC-SHA256, HKDF-SHA256, AES-256-GCM).

This does not use sgit-ai's code. It reimplements the read path from the
documented format, so it doubles as the specification for the Swift reader:

    read key (32 bytes) + vault id
      -> branch index file id = "idx-pid-muw-" + HMAC(read_key, "sg-vault-v1:file-id:branch-index:<vault_id>")[:12 hex]
      -> ref file id          = "ref-pid-muw-" + HMAC(read_key, "sg-vault-v1:file-id:ref:<vault_id>")[:12 hex]
      -> ref    (AES-GCM)     = {"commit_id": "obj-cas-imm-…"}
      -> commit (AES-GCM)     = {tree_id, parents, message_enc, timestamp_ms, …}
      -> tree   (AES-GCM)     = {entries: [{name_enc, blob_id | tree_id, size_enc, …}]}
      -> blob   (AES-GCM, optionally deflated: b"\\x00sgz1" + iv + GCM(zlib))

Every object is iv(12) + ciphertext + tag(16). Names inside trees are
base64(iv + GCM(name)).

Two sources, the same bytes:
    local   python3 -I vault_read_probe.py <clone-dir>
            reads <clone>/.sg_vault/bare/… after `sgit clone`
    remote  python3 -I vault_read_probe.py --remote <clone-dir>
            reads GET https://dev.send.sgraph.ai/api/vault/read/<vault_id>/bare/…
            (no auth header: the server holds only ciphertext)

The read key is taken from the clone's .sg_vault/local/clone_mode.json and is
never printed. Run with `python3 -I` from a directory you trust.
Verified on 7 Nov 2026 against vault i9mbeqwb (this app's source): 19 files,
README.md byte-identical to the sgit checkout, local and remote.
"""
import base64
import hashlib
import hmac
import json
import sys
import urllib.parse
import urllib.request
import zlib
from pathlib import Path

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

SERVER = 'https://dev.send.sgraph.ai'
MAGIC = b'\x00sgz1'


def main():
    remote = '--remote' in sys.argv
    clone = Path([a for a in sys.argv[1:] if a != '--remote'][0])
    meta = json.loads((clone / '.sg_vault' / 'local' / 'clone_mode.json').read_text())
    read_key, vault_id = bytes.fromhex(meta['read_key']), meta['vault_id']
    structure_key = HKDF(hashes.SHA256(), 32, None, b'sg-vault-v1:structure-key').derive(read_key)

    def fetch(path):
        if remote:
            url = f'{SERVER}/api/vault/read/{vault_id}/{urllib.parse.quote(path, safe="")}'
            with urllib.request.urlopen(url, timeout=30) as response:
                return response.read()
        return (clone / '.sg_vault' / path).read_bytes()

    def decrypt(data):
        for key in (read_key, structure_key):
            if data[:5] == MAGIC:
                try:
                    return zlib.decompress(AESGCM(key).decrypt(data[5:17], data[17:], None))
                except Exception:
                    pass
            try:
                return AESGCM(key).decrypt(data[:12], data[12:], None)
            except Exception:
                continue
        raise SystemExit('could not decrypt an object with the read key or the structure key')

    def file_id(domain):
        return hmac.new(read_key, f'{domain}:{vault_id}'.encode(), hashlib.sha256).hexdigest()[:12]

    def name(b64):
        return decrypt(base64.b64decode(b64)).decode()

    index = json.loads(decrypt(fetch(f'bare/indexes/idx-pid-muw-{file_id("sg-vault-v1:file-id:branch-index")}')))
    print('branch index :', index['schema'], '·', ', '.join(b['name'] for b in index['branches']))
    ref = json.loads(decrypt(fetch(f'bare/refs/ref-pid-muw-{file_id("sg-vault-v1:file-id:ref")}')))
    commit = json.loads(decrypt(fetch(f'bare/data/{ref["commit_id"]}')))
    print('head commit  :', ref['commit_id'], '·', name(commit['message_enc']))

    def walk(tree_id, prefix=''):
        for entry in json.loads(decrypt(fetch(f'bare/data/{tree_id}')))['entries']:
            path = prefix + name(entry['name_enc'])
            if entry.get('tree_id'):
                yield from walk(entry['tree_id'], path + '/')
            else:
                yield path, entry

    files = dict(walk(commit['tree_id']))
    print('files        :', len(files))
    readme = decrypt(fetch(f'bare/data/{files["README.md"]["blob_id"]}'))
    checkout = clone / 'README.md'
    same = checkout.exists() and checkout.read_bytes() == readme
    print('README.md    :', len(readme), 'bytes, identical to the sgit checkout:', same)
    print('source       :', 'remote ' + SERVER if remote else 'local clone')


if __name__ == '__main__':
    main()
