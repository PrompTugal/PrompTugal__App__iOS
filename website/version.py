#!/usr/bin/env python3
"""The repository's release version, v{major}.{minor}.{n}, kept in /VERSION.

CI bumps n once per push to dev, commits VERSION, tags it and pushes both
(.github/workflows/website.yml). Every app's version is this number without the
"v" (v0.4.7 -> 0.4.7): the iOS release workflow passes it to xcodebuild as
MARKETING_VERSION, so the app, the tag and the site agree.

To jump to a new minor, write v<major>.<minor> (no patch) into VERSION. The next
bump makes it v<major>.<minor>.0; read() shows that number meanwhile.

Usage: python3 website/version.py          print the current version
       python3 website/version.py bump     write and print the next version
"""
import re
import sys
from pathlib import Path

FILE = Path(__file__).resolve().parent.parent / 'VERSION'
PATTERN = re.compile(r'v(\d+)\.(\d+)(?:\.(\d+))?')


def parse(path=FILE):
    text = path.read_text().strip()
    match = PATTERN.fullmatch(text)
    if not match:
        raise SystemExit(f'version: {path} holds {text!r}, wants v<major>.<minor>.<n> or v<major>.<minor>')
    return match.groups()


def read(path=FILE):
    major, minor, n = parse(path)
    return f'v{major}.{minor}.{n or 0}'


def bump(path=FILE):
    major, minor, n = parse(path)
    # v0.4 (no patch) means "the next release is v0.4.0"; v0.4.3 means v0.4.4.
    new = f'v{major}.{minor}.0' if n is None else f'v{major}.{minor}.{int(n) + 1}'
    path.write_text(new + '\n')
    return new


if __name__ == '__main__':
    print(bump() if sys.argv[1:] == ['bump'] else read())
