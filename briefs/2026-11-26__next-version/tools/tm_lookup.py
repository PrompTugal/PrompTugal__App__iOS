"""Look up the translations of a by-place file's prose in PrompTugal.news's translation memory.
usage: python3 -I tm_lookup.py <place-id> <culture>"""
import hashlib, json, re, sys, unicodedata, urllib.request, urllib.error
SITE = "https://promptugal.news"
def get(u):
    with urllib.request.urlopen(u, timeout=30) as r: return json.loads(r.read())
def norm(s):  # board/team/translator/tools/tm.mjs
    s = unicodedata.normalize("NFC", s).replace("\r\n", "\n").replace("\r", "\n")
    s = re.sub(r"[ \t ]+", " ", s); s = re.sub(r" ?\n ?", "\n", s); s = re.sub(r"\n{3,}", "\n\n", s)
    return s.strip()
def key(s): return hashlib.sha256(norm(s).encode("utf-8")).hexdigest()[:16]
def strings(place):
    out = []
    for n in place.get("ai_news") or []:
        out += [n.get("title"), n.get("summary")]
    for k in ("mandate", "gravity"): out.append(place.get(k))
    v = place.get("voice")
    if isinstance(v, dict): out += [x for x in v.values() if isinstance(x, str)]
    return [s for s in out if isinstance(s, str) and s.strip()]
def main(pid, culture):
    data = get(f"{SITE}/api/v1/by-place/{pid}.json")
    place = data.get("place") if isinstance(data.get("place"), dict) else data
    shards, hits, rows = {}, 0, []
    ss = strings(place)
    for s in ss:
        k = key(s); shard = k[:2]
        if shard not in shards:
            try: shards[shard] = get(f"{SITE}/data/i18n/tm/{culture}/{shard}.json")
            except urllib.error.HTTPError: shards[shard] = {}
        e = shards[shard].get(k)
        if e: hits += 1; rows.append((s[:60], e["t"][:60], e.get("ok")))
    print(f"{pid} {culture}: {hits} of {len(ss)} strings translated")
    for r in rows[:4]: print("  ", r)
if __name__ == "__main__": main(sys.argv[1], sys.argv[2])
