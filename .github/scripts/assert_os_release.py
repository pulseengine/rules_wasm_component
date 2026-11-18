#!/usr/bin/env python3
"""assert_os_release.py — fail unless os-release names the expected distribution.

The "Compatibility Tests (ubuntu-22.04)" job runs in an ubuntu:22.04 container
on an ubuntu-24.04 runner (rivet DD-004, REQ-005). This step proves the
container is in effect: without it, a dropped `container:` line would test the
24.04 host while the check name still says 22.04.

  assert_os_release.py --id ubuntu --version-id 22.04 [--file PATH]

PATH defaults to /etc/os-release. Python 3.9+ (the container has 3.10).

rivet: verifies REQ-005
"""
import argparse
import sys


def parse(text):
    fields = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        fields[key] = value.strip().strip('"').strip("'")
    return fields


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--id", required=True)
    ap.add_argument("--version-id", required=True)
    ap.add_argument("--file", default="/etc/os-release")
    a = ap.parse_args()
    try:
        with open(a.file) as f:
            fields = parse(f.read())
    except OSError as e:
        print(f"os-release floor: cannot read {a.file}: {e}", file=sys.stderr)
        return 1
    found = (fields.get("ID", "?"), fields.get("VERSION_ID", "?"))
    if found != (a.id, a.version_id):
        print(f"os-release floor: expected {a.id} {a.version_id}, found {found[0]} {found[1]} in {a.file}",
              file=sys.stderr)
        return 1
    print(f"os-release floor: {a.id} {a.version_id} ({a.file})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
