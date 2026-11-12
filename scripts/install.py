#!/usr/bin/env python3
"""Install this repository's Omarchy plugin snapshots with backups."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
ROOT_FILES = ('manifest.json', 'Status.qml', 'ThemePalette.qml', 'i18n')


def packages():
    sources = [REPO, *sorted((REPO / 'plugins').iterdir())]
    result = []
    for source in sources:
        manifest = json.loads((source / 'manifest.json').read_text())
        subprocess.run(['omarchy', 'plugin', 'validate', str(source)], check=True)
        result.append((manifest['id'], source))
    return result


def install(config_dir, apply_layout=False, reload_shell=True, dry_run=False):
    selected = packages()
    config_dir = Path(config_dir).expanduser().resolve()
    plugins = config_dir / 'plugins'
    config = config_dir / 'shell.json'
    original = config.read_bytes() if config.exists() else None
    layout = None
    if apply_layout:
        dependency = plugins / 'whitewebdev.flat-tray/manifest.json'
        if not dependency.is_file() or json.loads(dependency.read_text()).get('id') != 'whitewebdev.flat-tray':
            raise RuntimeError('Full layout requires whitewebdev.flat-tray; install it as described in README.md.')
        layout = json.loads(original) if original is not None else {'version': 1}
        layout['bar'] = json.loads((REPO / 'presets/dwm-bar.json').read_text())['bar']
    for plugin_id, _ in selected:
        print(f'{plugin_id} -> {plugins / plugin_id}')
    if dry_run:
        if apply_layout:
            print(f'Would apply bar preset to {config}; unrelated settings are preserved.')
        return None
    plugins.mkdir(parents=True, exist_ok=True)
    backup_root = config_dir / 'backups'
    backup_root.mkdir(exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path(tempfile.mkdtemp(prefix=f'dwm-bar-{stamp}-', dir=backup_root))
    if original is not None:
        (backup / 'shell.json').write_bytes(original)
    moved = []
    installed = []
    try:
        with tempfile.TemporaryDirectory(prefix='.dwm-stage-', dir=plugins) as staging:
            for plugin_id, source in selected:
                stage = Path(staging) / plugin_id
                if source == REPO:
                    stage.mkdir()
                    for name in ROOT_FILES:
                        item = source / name
                        if item.is_dir():
                            shutil.copytree(item, stage / name)
                        else:
                            shutil.copy2(item, stage / name)
                else:
                    shutil.copytree(source, stage, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
                for name in ('LICENSE', 'NOTICE'):
                    shutil.copy2(REPO / name, stage / name)
                destination = plugins / plugin_id
                if destination.exists() or destination.is_symlink():
                    saved = backup / plugin_id
                    destination.rename(saved)
                    moved.append((destination, saved))
                stage.rename(destination)
                installed.append(destination)
            if layout is not None:
                pending = Path(staging) / 'shell.json'
                pending.write_text(json.dumps(layout, indent=2) + '\n')
                os.replace(pending, config)
    except Exception:
        for destination in reversed(installed):
            shutil.rmtree(destination)
        for destination, saved in reversed(moved):
            saved.rename(destination)
        if original is not None:
            config.write_bytes(original)
        elif config.exists() and layout is not None:
            config.unlink()
        raise
    print(f'Backup: {backup}')
    if reload_shell:
        try:
            subprocess.run(['omarchy', 'restart', 'shell'], check=True)
        except (OSError, subprocess.CalledProcessError):
            print('Files installed. Restart manually when a graphical session is available: omarchy restart shell')
    return backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply-layout', action='store_true', help='Apply the bundled bar preset while preserving unrelated shell settings')
    parser.add_argument('--config-dir', type=Path, default=Path.home() / '.config/omarchy')
    parser.add_argument('--no-reload', action='store_true', help='Do not restart the graphical shell')
    parser.add_argument('--dry-run', action='store_true', help='Validate and describe changes without writing files')
    args = parser.parse_args()
    try:
        install(args.config_dir, args.apply_layout, not args.no_reload, args.dry_run)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Install failed: {error}\n')


if __name__ == '__main__':
    main()
