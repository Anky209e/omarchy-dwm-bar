#!/usr/bin/env python3
"""Validate every Omarchy manifest and run isolated regression checks."""
import os
from pathlib import Path
import subprocess
import sys

repo = Path(__file__).resolve().parents[1]
env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
for plugin in [repo, *sorted((repo / 'plugins').iterdir())]:
    subprocess.run(['omarchy', 'plugin', 'validate', str(plugin)], check=True)
    print(f'Validated: {plugin.relative_to(repo) if plugin != repo else "root"}', flush=True)
subprocess.run(['node', 'tests/parsers.test.js'], cwd=repo, env=env, check=True)
subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py', '-v'], cwd=repo, env=env, check=True)
