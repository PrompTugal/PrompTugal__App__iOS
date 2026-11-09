#!/usr/bin/env python3
"""Make the RiskMandate business card's Apple Wallet pass, signed, from the App Store Connect API.

conductor@web-summit.indi, 9 November 2026, at Dinis's word ("Dinis gives access for you to make the pass").
The pass's design is the team site's green card (SGit-AI/SGit-AI__Website__Web-Summit, team/designer/wallet/).

    python3 scripts/wallet/wallet_pass.py --out card.pkpass [--confirm]

1. Finds or creates the Pass Type ID (POST /v1/passTypeIds), default pass.news.promptugal.card.
2. Makes a new RSA key and a certificate signing request on this runner, and asks App Store Connect for a
   PASS_TYPE_ID certificate linked to that ID (POST /v1/certificates with a passTypeId relationship).
3. Downloads Apple's WWDR G4 intermediate certificate.
4. Builds manifest.json, signs it (openssl smime, DER, detached), and zips the .pkpass.
The private key lives only in a temporary folder and is deleted at the end; it is never printed, uploaded or
committed. Without --confirm, it only lists what exists and what it would create. Needs ASC_KEY_ID, ASC_ISSUER_ID,
ASC_KEY_P8_BASE64 and APPLE_TEAM_ID (the release workflows' secrets). Standard library and openssl only.
"""
import argparse, base64, hashlib, json, os, subprocess, sys, tempfile, urllib.request, zipfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'release'))
import asc  # noqa: E402  (token, call, say)

HERE = os.path.dirname(os.path.abspath(__file__))
WWDR = 'https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer'


def main():
    a = argparse.ArgumentParser()
    a.add_argument('--out', default='card.pkpass')
    a.add_argument('--identifier', default='pass.news.promptugal.card')
    a.add_argument('--confirm', action='store_true')
    o = a.parse_args()
    team = os.environ.get('APPLE_TEAM_ID', '').strip()
    if not team:
        sys.exit('::error::APPLE_TEAM_ID is not set')

    found = asc.call('GET', f'/v1/passTypeIds?filter[identifier]={o.identifier}')['data']
    asc.say(f'Pass Type ID {o.identifier}: {"exists" if found else "not yet created"}')
    if not o.confirm:
        asc.say('Plan only (tick "confirm" to create the ID if needed, a new pass certificate, and the signed pass).')
        return 0
    if found:
        pid = found[0]['id']
    else:
        pid = asc.call('POST', '/v1/passTypeIds', {'data': {'type': 'passTypeIds', 'attributes': {
            'identifier': o.identifier, 'name': 'RiskMandate business card'}}})['data']['id']
        asc.say(f'Created the Pass Type ID {o.identifier}')

    with tempfile.TemporaryDirectory() as tmp:
        key, csr = os.path.join(tmp, 'pass.key'), os.path.join(tmp, 'pass.csr')
        subprocess.run(['openssl', 'req', '-new', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', csr,
                        '-subj', f'/CN={o.identifier}/O=RiskMandate'], check=True, capture_output=True)
        csr_body = ''.join(l for l in open(csr).read().splitlines() if not l.startswith('-----'))
        cert = asc.call('POST', '/v1/certificates', {'data': {'type': 'certificates',
            'attributes': {'certificateType': 'PASS_TYPE_ID', 'csrContent': csr_body},
            'relationships': {'passTypeId': {'data': {'type': 'passTypeIds', 'id': pid}}}}})['data']
        asc.say(f'Created a pass certificate, expires {cert["attributes"].get("expirationDate", "?")}')
        der = base64.b64decode(cert['attributes']['certificateContent'])
        cert_pem = os.path.join(tmp, 'pass.pem')
        subprocess.run(['openssl', 'x509', '-inform', 'DER', '-out', cert_pem], input=der, check=True)
        wwdr_pem = os.path.join(tmp, 'wwdr.pem')
        with urllib.request.urlopen(WWDR, timeout=60) as r:
            subprocess.run(['openssl', 'x509', '-inform', 'DER', '-out', wwdr_pem], input=r.read(), check=True)

        files = {}
        for name in sorted(os.listdir(os.path.join(HERE, 'pass'))):
            if name.startswith('.'):
                continue
            data = open(os.path.join(HERE, 'pass', name), 'rb').read()
            if name == 'pass.json':
                p = json.loads(data)
                p['teamIdentifier'], p['passTypeIdentifier'] = team, o.identifier
                data = json.dumps(p, indent=1, ensure_ascii=False).encode()
            files[name] = data
        manifest = json.dumps({n: hashlib.sha1(d).hexdigest() for n, d in files.items()}, indent=1).encode()
        files['manifest.json'] = manifest
        mf, sig = os.path.join(tmp, 'manifest.json'), os.path.join(tmp, 'signature')
        open(mf, 'wb').write(manifest)
        subprocess.run(['openssl', 'smime', '-binary', '-sign', '-certfile', wwdr_pem, '-signer', cert_pem,
                        '-inkey', key, '-in', mf, '-out', sig, '-outform', 'DER'], check=True)
        files['signature'] = open(sig, 'rb').read()
        with zipfile.ZipFile(o.out, 'w', zipfile.ZIP_DEFLATED) as z:
            for n, d in files.items():
                z.writestr(n, d)
    asc.say(f'Wrote {o.out} ({os.path.getsize(o.out)} bytes), signed for {o.identifier}. The private key is deleted.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
