#!/usr/bin/env python3
"""The repository's release version, v{major}.{minor}.{n}, kept in /VERSION.

CI bumps n once per push to dev, commits VERSION, tags it and pushes both
(.github/workflows/website.yml). The app's own version is separate: it is
MARKETING_VERSION in the Xcode project, bumped by hand for each TestFlight build.

Usage: python3 website/version.py          print the current version
       python3 website/version.py bump     write and print the next version
"""
import re
import sys
from pathlib import Path

FILE = Path(__file__).resolve().parent.parent / 'VERSION'
PATTERN = re.compile(r'v(\d+)\.(\d+)\.(\d+)')


def read(path=FILE):
    text = path.read_text().strip()
    if not PATTERN.fullmatch(text):
        raise SystemExit(f'version: {path} holds {text!r}, wants v<major>.<minor>.<n>')
    return text


def bump(path=FILE):
    major, minor, n = PATTERN.fullmatch(read(path)).groups()
    new = f'v{major}.{minor}.{int(n) + 1}'
    path.write_text(new + '\n')
    return new


if __name__ == '__main__':
    print(bump() if sys.argv[1:] == ['bump'] else read())
