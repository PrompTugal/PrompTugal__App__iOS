"""Verify a PrompTugal.news article signature (form twin-without-version-or-builder/2).
usage: python3 -I verify_article.py <slug> [<slug> ...]   (reads the live site)"""
import base64, hashlib, json, re, sys, urllib.request
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature
from cryptography.exceptions import InvalidSignature

SITE = "https://promptugal.news"

def get(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read()

LEGACY_BUILT_BY = "built by: newsroom@web-summit.dinis (a Claude Code session), operator Dinis Cruz"

def no_version(twin: str) -> str:
    twin = re.sub(r"^(\*Source: <[^>\n]+> · site )v\d+\.\d+\.\d+( ·)", r"\g<1>VERSION\g<2>", twin, count=1, flags=re.M)
    return re.sub(r"^version: v\d+\.\d+\.\d+$", "version: VERSION", twin, count=1, flags=re.M)

def last_built_by(twin: str, line: str) -> str:
    last = None
    for m in re.finditer(r"^built by: .*$", twin, flags=re.M):
        last = m
    return twin if last is None else twin[:last.start()] + line + twin[last.end():]

def signed_form(twin: str, form: str = "twin-without-version-or-builder/2") -> str:
    """The bytes a signature covers (newsroom/build/signed-form.cjs, signedFormFor)."""
    if form == "twin-without-version-or-builder/2":
        return last_built_by(no_version(twin), "built by: BUILDER")
    if form == "twin-without-version/1":
        return no_version(last_built_by(twin, LEGACY_BUILT_BY))
    return twin  # no form: the oldest signatures cover the twin exactly as it was built (breaks at every release)

def fingerprint(spki_pem: str) -> str:
    der = serialization.load_pem_public_key(spki_pem.encode()).public_bytes(
        serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    return "sha256:" + hashlib.sha256(der).hexdigest()[:16]

def main(slugs):
    keys = json.loads(get(SITE + "/board/keys.json"))["keys"]
    ok = True
    for slug in slugs:
        twin = get(f"{SITE}/articles/{slug}.md").decode("utf-8")
        sig = json.loads(get(f"{SITE}/articles/{slug}.md.sig"))
        form = sig.get("form")
        key = next((k for k in keys if (k.get("bundle") or {}).get("signing_fingerprint") == sig["fingerprint"]), None)
        if key is None:
            print(f"{slug}: UNKNOWN KEY {sig['fingerprint']} (not in board/keys.json)"); ok = False; continue
        pem = key["bundle"]["sign"]
        pub = serialization.load_pem_public_key(pem.encode())
        assert isinstance(pub, ec.EllipticCurvePublicKey) and pub.curve.name == "secp256r1"
        assert fingerprint(pem) == sig["fingerprint"], (fingerprint(pem), sig["fingerprint"])
        raw = base64.b64decode(sig["signature"])          # 64 bytes: r || s (WebCrypto's raw form)
        der = encode_dss_signature(int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big"))
        data = signed_form(twin, form).encode("utf-8")
        try:
            pub.verify(der, data, ec.ECDSA(hashes.SHA256()))
            verdict = "VALID"
        except InvalidSignature:
            verdict, ok = "INVALID", False
        print(f"{slug}: {verdict} (form {form}) by {key['id']} ({key['agent']}, status {key.get('status')}), "
              f"{len(data)} bytes signed, sha256 {hashlib.sha256(data).hexdigest()[:16]}")
    return ok

if __name__ == "__main__":
    sys.exit(0 if main(sys.argv[1:]) else 1)
