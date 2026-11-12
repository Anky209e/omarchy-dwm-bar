# Omarchy DWM Bar

A compact, dwm-style top bar built on Omarchy's stock Quickshell bar. It follows the active Omarchy theme and keeps live readings in fixed-width click targets.

```text
LEFT   workspaces → layout → music
RIGHT  CPU | RAM | GPU | VOL | TEMP | date/time | state icons | connections | tray
```

Music replaces the window title and uses the theme accent while playing. CPU, RAM, GPU, volume and temperature use distinct colors from the current theme. Idle, night light, recording and do-not-disturb controls remain visible in a fixed order; nothing expands on hover. There is no DEV shortcut or focus timer.

## Requirements

- Omarchy with its Quickshell shell, `qs.Ui`, `qs.Commons`, and the `omarchy plugin` commands. Developed against the installed shell in November 2026; older Waybar-based releases are not supported.
- Python 3, `awk`, GNU `timeout`, and `wpctl` for local status reads.
- An NVIDIA GPU and working `nvidia-smi` for GPU load and temperature. The current implementation reads GPU index `0`; unavailable readings display `—` without collapsing their slots. AMD and Intel sensors are not implemented.
- `btop` and `nvtop` for click-through monitoring.
- An MPRIS-compatible player for music controls. Without a player, the music slot shows “No music.”
- A Nerd Font for shell icons, normally provided by Omarchy.
- [Flat Tray](https://github.com/WhiteWebDev/omarchy-flat-tray) for the complete bar preset. The repository does not vendor or automatically download that dependency.

## Install the complete bar

From this checkout, first install Flat Tray if it is not already present:

```bash
omarchy plugin add https://github.com/WhiteWebDev/omarchy-flat-tray.git
python scripts/install.py --dry-run --apply-layout
python scripts/install.py --apply-layout
```

The installer validates all six manifests, copies the plugin files into `~/.config/omarchy/plugins/`, applies only the `bar` subtree of `shell.json`, and restarts the shell. Existing idle settings and unrelated plugins remain intact. Replaced plugin directories and the previous `shell.json` are saved under `~/.config/omarchy/backups/dwm-bar-<timestamp>-<suffix>/`. Installation file failures roll back the copied plugins and configuration.

To update plugin code without resetting your customized layout:

```bash
python scripts/install.py
```

Installed files are snapshots, not symlinks. Edit this checkout and rerun the installer to deploy changes. `--no-reload` skips restarting the shell; `--config-dir PATH` supports isolated installation checks.

## Omarchy plugin format

Omarchy's Git installer accepts one root `manifest.json`. This repository's root is the independently installable `anky.dwm-status` bar widget. The other pieces live in `plugins/`, each with its own schema-version-1 manifest and relative QML entry point:

| Plugin ID | Role |
| --- | --- |
| `anky.dwm-status` | CPU, RAM, GPU utilization and volume text |
| `anky.workspaces` | Numbered tags, occupied indicators and layout switch |
| `anky.music` | Fixed-width MPRIS music display and playback controls |
| `anky.temperature` | Independent NVIDIA GPU temperature widget |
| `anky.indicators` | Fixed-order idle, night light, recording and DND controls |
| `anky.divider` | Reusable theme-colored separators |

Running `omarchy plugin add <git-url> --enable` against a future published copy installs **only the root status widget**. Use the local installer above for the complete bar. Existing installs with the same IDs should use the installer rather than `plugin add`.

The preset uses Omarchy's native clock, audio, network, Bluetooth, power and keyboard widgets, plus Flat Tray. Those native controls retain their normal panels. Temperature is deliberately separate from GPU utilization. Old experimental bar replacements, window titles, timers, backups, machine-specific idle settings and unused scripts are excluded from this repository.

## Controls

| Item | Action |
| --- | --- |
| Workspace tag | Left click selects the workspace; right click opens Omarchy's menu; wheel navigates workspaces |
| Layout symbol | Click cycles the workspace layout; `[]=` tiled, `|||` scrolling, `><>` floating |
| Music | Left click play/pause; right click next; middle click previous |
| CPU or RAM | Open `btop` |
| GPU or temperature | Open `nvtop` |
| Volume text | Left click opens audio; right click mutes/unmutes; wheel changes volume in 5% steps, capped at 100% |
| Date/time | Native calendar and alternate date-format controls |
| Coffee icon | Toggle stay-awake / normal idle locking |
| Night-light icon | Toggle night light |
| Recording icon | Open recording choices, or stop an active recording |
| DND icon | Toggle notification silencing |
| Native connection, audio and power icons | Open their normal Omarchy panels |
| Tray icons | Normal application actions and context menus |

Music titles are elided instead of scrolling. User-controlled titles are bounded and displayed as plain text, and are never placed in tooltips. Sensor reads use fixed command argument arrays, numeric validation and timeouts. The widgets do not access the network.

## Theme colors and status

Palette files are read from Omarchy's current theme, with semantic colors falling back to the theme accent. Theme color changes reload the palette.

| Widget | Normal | State change |
| --- | --- | --- |
| CPU | Theme green | Theme red at 90% |
| RAM | Theme blue | Theme red at 90% |
| GPU | Theme magenta | Theme yellow at 95%; muted when unavailable |
| Volume | Theme cyan | Muted palette color while muted |
| GPU temperature | Theme cyan | Theme yellow at 75°C; theme red at 85°C; muted when unavailable |
| Music | Theme accent while playing | Muted while paused or absent |
| Stay-awake / night light / recording / DND | Muted when off | Theme cyan / yellow / red / magenta when on |

CPU, RAM and volume refresh every two seconds. GPU utilization, temperature and corner state controls refresh every five seconds. Each monitor hosts its own readers. Actions also request a state refresh; native state changes may take up to one poll interval to appear. NVIDIA polling can wake a sleeping discrete GPU and consume additional battery power.

The preset captures the current glassy top-bar background. Change it with `omarchy bar background opaque`, `glassy`, or `none`; this does not affect the palette used by individual widgets.

## Validation and tests

```bash
python scripts/check.py
```

This validates every manifest with Omarchy, runs JavaScript parser checks with Node.js, and tests installation against temporary configuration directories. Tests cover malformed sensor values, markup-shaped input, bounded theme parsing, preserved unrelated settings, backup contents, missing dependencies, dry runs and rollback. They do not toggle desktop settings or start screen recording.

For runtime validation after installing:

```bash
omarchy-shell shell ping
omarchy plugin list --json
```

## Restore

Use the backup path printed by the installer. Copy its `shell.json` back to `~/.config/omarchy/shell.json` and restore any backed-up plugin directories you want to revert, then run `omarchy restart shell`. Newly added plugin directories can remain installed but inactive after restoring the old layout.

## License

MIT. The workspace implementation derives from Omarchy; see [NOTICE](NOTICE) and [LICENSE](LICENSE). Flat Tray is maintained separately.
