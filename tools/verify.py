#!/usr/bin/env python3
"""Cross-platform release gate. No live-client actions or external publishing."""

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    print("+ " + " ".join(args), flush=True)
    subprocess.run(args, cwd=ROOT, check=True)


(ROOT / "preview").mkdir(exist_ok=True)
run("python3", "tools/build_data.py")
run("python3", "tools/sync_core.py")
for suite in [
    "core",
    "regressions",
    "auto_level",
    "nodes",
    "portability",
    "simulation",
    "ui",
    "simple_view",
    "skill_updates",
    "workflow_ux",
    "client_talents",
    "training",
    "build_links",
]:
    run("lua5.1", f"tests/test_{suite}.lua")
run("python3", "tools/check_package.py", "--source-only")
run("node", "--test", "tests/web/engine.test.mjs")
run("python3", "tools/sync_core.py", "--check")
print("Shared engine, native addon, portable formats and PWA parity passed.")
