# Omarchy DWM Bar

One Omarchy shell plugin for the complete dwm-style top bar. Workspaces, layout switching, music, text metrics, temperature, state controls and a flat system tray are bundled together. No companion plugins, installer script, layout copying or separate tray installation.

## Install

```bash
omarchy plugin install https://github.com/Anky209e/omarchy-dwm-bar.git --enable
```

`install` is Omarchy's alias for `plugin add`. `--enable` selects the bar immediately after installation. The plugin ID is **`anky.dwm-bar`**. Omarchy handles cloning, validation and enabling; its normal review/confirmation prompt still applies.

To update an installed copy:

```bash
omarchy plugin update anky.dwm-bar
```

To switch between bars without removing this plugin:

```bash
omarchy bar use omarchy.bar
omarchy bar use anky.dwm-bar
```

The original `bar.layout`, idle settings and unrelated plugins remain in `shell.json`. Enabling this plugin selects `bar.id`; the plugin supplies its own layout at runtime. To remove it, first select `omarchy.bar`, then run `omarchy plugin remove anky.dwm-bar`.

## Layout

```text
LEFT   workspaces → layout symbol → music
RIGHT  CPU | RAM | GPU | VOL | TEMP | date/time | idle/night/recording/DND | connections | tray
```

- Numbered workspace tags with a solid active-tag highlight and occupied markers.
- `[]=` tiled, `|||` scrolling and `><>` floating layout symbols.
- Fixed-width, elided music title; the theme accent is used while playing.
- Tight CPU, RAM, GPU and volume text blocks, plus an independent temperature block.
- Fixed-order corner controls. Nothing expands on hover.
- Native Omarchy calendar, network, Bluetooth, audio, power and keyboard controls.
- The flat tray implementation is included under its MIT license; a separate Flat Tray plugin is unnecessary. Its icons appear when applications register tray items. Keyboard layout follows Omarchy's normal visibility rules.

The bar always sits at the top. It respects the current background setting: `omarchy bar background opaque`, `glassy`, or `none`. The layout itself is defined in `DwmBar.qml`; dragging or changing the old stock bar's widget list does not change this bundled layout.

## Controls

| Item | Action |
| --- | --- |
| Workspace tag | Left click selects; right click opens Omarchy's menu; wheel navigates |
| Layout symbol | Click cycles the current workspace layout |
| Music | Left click play/pause; right click next; middle click previous |
| CPU / RAM | Left click opens `btop`; right click refreshes hardware once |
| GPU / temperature | Left click opens `nvtop`; right click refreshes hardware once |
| Volume text | Left click opens audio; right click mutes; wheel adjusts by 5%, capped at 100% |
| Date/time | Open Omarchy's calendar |
| Coffee icon | Toggle stay-awake / normal idle locking |
| Night light | Toggle screen temperature |
| Recording | Open recording choices, or stop an active recording |
| DND | Toggle notification silencing |
| Native connection, audio and power icons | Open their normal panels |
| Tray | Application actions and context menus |

There is no window-title widget, DEV shortcut or focus timer.

## Theme colors

All colors come from the current Omarchy palette; semantic colors fall back to the theme accent. Theme changes reload the palette.

| Widget | Normal | State change |
| --- | --- | --- |
| CPU | Green | Red at 90% |
| RAM | Blue | Red at 90% |
| GPU | Magenta | Yellow at 95%; muted when unavailable |
| Volume | Cyan | Muted when muted |
| GPU temperature | Cyan | Yellow at 75°C; red at 85°C; muted when unavailable |
| Music | Accent while playing | Muted when paused or absent |
| Idle / night / recording / DND | Muted when off | Cyan / yellow / red / magenta when on |

## Requirements and behavior

Requires Omarchy's Quickshell shell and plugin CLI, including the full-bar API, `qs.Ui` and `qs.Commons`. Older Waybar releases are unsupported. The bar extends the installed `/usr/share/omarchy/shell/plugins/bar/Bar.qml`, without modifying or copying packaged Omarchy source.

Python 3, `awk`, GNU `timeout`, `wpctl` and a Nerd Font are normally provided by Omarchy. `btop` and `nvtop` are needed for monitoring shortcuts. Music uses MPRIS; without a compatible player the slot says “No music.” NVIDIA GPU index `0` is read through `nvidia-smi`; Intel/AMD GPU sensors are not implemented. Unsupported or missing readings display `—` and retain their space.

One shared telemetry object serves every monitor. CPU and RAM refresh every two seconds. GPU utilization and temperature are read together in one bounded `nvidia-smi` query every five seconds. Volume follows PipeWire events; idle, night light and DND follow Omarchy service events. Only screen-recording status retains a shared five-second check. Extra monitors do not create extra polling processes. NVIDIA polling outside gaming mode may still wake a sleeping discrete GPU and consume battery power. The plugin itself makes no network requests.

## Gaming efficiency

When a recognized game is in real fullscreen on a visible workspace on either monitor, automatic CPU/RAM and GPU/temperature polling pauses. Existing hardware values remain in their fixed slots, shown in the theme's muted color. Music, volume, date/time, recording controls and tray interaction continue normally. This changes bar telemetry only: it does not alter power profiles, notifications, idle locking, game settings or system performance governors.

Fullscreen changes, workspace changes and window/monitor lifecycle events trigger a debounced detection probe; there is no periodic game-detection poll. Steam game window classes and positive `SteamAppId`/`SteamGameId` process metadata are recognized, along with a small list of known native game classes. Only those Steam identifiers are read from a bounded environment buffer; environments are never returned or logged. A fullscreen browser, maximized window, or game on an invisible workspace does not trigger the policy.

Right-click CPU, RAM, GPU or TEMP to take a fresh hardware snapshot even while automatic polling is paused. The CPU snapshot samples a short interval; resuming normal polling resets its baseline so an entire gaming session is not averaged into the next reading. Polling resumes after leaving fullscreen, switching away from all fullscreen games, or closing the game.

For games not detected automatically, add exact window classes to the existing `bar` object in `~/.config/omarchy/shell.json`:

```json
{
  "gamingEfficiency": true,
  "gameClasses": ["YourGameClass", "AnotherGame.exe"]
}
```

These are fields inside `bar`, not a replacement for the whole file. Class matching is case-insensitive and exact. Set `gamingEfficiency` to `false` to keep hardware polling active during games. No additional plugin is required.

To inspect the shared reader or request a manual sample from the terminal:

```bash
omarchy-shell dwm.bar telemetry
omarchy-shell dwm.bar refresh
```

Music metadata is bounded and rendered as plain text. It is never used in a tooltip or shell command. Sensor values are validated, reads use timeouts and fixed command arguments, and click target widths stay stable as readings change.

## Repository format

There is exactly one root `manifest.json`, with `kinds: ["bar"]` and `entryPoints.bar: "DwmBar.qml"`. `widgets/` contains private QML components, translations and helpers, not independently installed plugins. The bar merges these components into the native widget registry while retaining the system panel implementations.

Version 2 replaces the original multi-plugin package. Existing `anky.dwm-status`, `anky.workspaces`, `anky.music`, `anky.temperature`, `anky.indicators` and `anky.divider` installations are no longer used by the active full bar. They can remain available for rollback; new installs need only `anky.dwm-bar`.

## Validation

```bash
python scripts/check.py
python scripts/check.py --runtime
```

The default check validates the single root manifest, bundled assets, numeric parsers, bounded theme input, plain-text music, complete runtime layout, preservation of prior settings, registry reinjection, shared-reader ownership, pause/manual/resume behavior, combined GPU parsing and conservative game classification. `--runtime` additionally checks the active graphical bar's actual component geometry, including that no old companion widget is rendering. Neither command toggles desktop settings or starts recording. Node.js is required only for these tests.

## License

MIT. Workspace code derives from Omarchy. Flat Tray is vendored from [WhiteWebDev/omarchy-flat-tray](https://github.com/WhiteWebDev/omarchy-flat-tray) with its license preserved. See [NOTICE](NOTICE), [LICENSE](LICENSE) and [the tray license](widgets/tray/LICENSE).
