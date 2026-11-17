#!/usr/bin/env python3
"""Run the planted controls in ci-controls.toml (pulseengine/plant format).

For each control, in a scratch copy of the repository (the working tree is
never touched):
  1. run the check unplanted: it must pass, otherwise a red baseline would
     make the planted run prove nothing;
  2. overlay the `plant` directory onto the copy and run the check again: it
     must fail (`expect = "fail"`), and its output must match
     `stderr_or_stdout_matches` when given.
Exits non-zero when any control's check stays green on its planted input, or
when the manifest lists no control at all.
"""
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

try:
    import tomllib
except ImportError:  # Python < 3.11
    sys.exit("run_ci_controls.py needs Python 3.11+ (tomllib)")

ROOT = pathlib.Path(__file__).resolve().parents[2]
SKIP = shutil.ignore_patterns(".git", "bazel-*", "node_modules", "target")


def run(cmd, cwd):
    p = subprocess.run(shlex.split(cmd), cwd=cwd, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def main():
    controls = tomllib.loads((ROOT / "ci-controls.toml").read_text()).get("control", [])
    if not controls:
        sys.exit("FAIL  ci-controls.toml lists no control: nothing was compared")
    failures = 0
    for c in controls:
        if c.get("expect", "fail") != "fail":
            sys.exit(f"FAIL  {c['id']}: only expect = \"fail\" is supported")
        with tempfile.TemporaryDirectory() as d:
            copy = pathlib.Path(d) / "repo"
            shutil.copytree(ROOT, copy, ignore=SKIP, symlinks=True)
            code, out = run(c["run"], copy)
            if code != 0:
                print(f"FAIL  {c['id']}: baseline is already red (exit {code}):\n{out}")
                failures += 1
                continue
            shutil.copytree(ROOT / c["plant"], copy, dirs_exist_ok=True)
            code, out = run(c["run"], copy)
            pattern = c.get("stderr_or_stdout_matches")
            if code == 0:
                print(f"FAIL  {c['id']}: '{c['check']}' stayed green on the planted input")
                failures += 1
            elif pattern and not re.search(pattern, out):
                print(f"FAIL  {c['id']}: planted run failed, but not with /{pattern}/:\n{out}")
                failures += 1
            else:
                print(f"ok    {c['id']}: '{c['check']}' passes the baseline and rejects the plant (exit {code})")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
