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
| CPU / RAM | Open `btop` |
| GPU / temperature | Open `nvtop` |
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

CPU, RAM and volume refresh every two seconds; GPU, temperature and corner states every five seconds. Each monitor hosts its own readers. NVIDIA polling may wake a sleeping discrete GPU and consume battery power. The plugin itself makes no network requests.

Music metadata is bounded and rendered as plain text. It is never used in a tooltip or shell command. Sensor values are validated, reads use timeouts and fixed command arguments, and click target widths stay stable as readings change.

## Repository format

There is exactly one root `manifest.json`, with `kinds: ["bar"]` and `entryPoints.bar: "DwmBar.qml"`. `widgets/` contains private QML components, translations and helpers, not independently installed plugins. The bar merges these components into the native widget registry while retaining the system panel implementations.

Version 2 replaces the original multi-plugin package. Existing `anky.dwm-status`, `anky.workspaces`, `anky.music`, `anky.temperature`, `anky.indicators` and `anky.divider` installations are no longer used by the active full bar. They can remain available for rollback; new installs need only `anky.dwm-bar`.

## Validation

```bash
python scripts/check.py
python scripts/check.py --runtime
```

The default check validates the single root manifest, bundled assets, numeric parsers, bounded theme input, plain-text music, complete runtime layout, preservation of prior settings and registry reinjection. `--runtime` additionally checks the active graphical bar's actual component geometry, including that no old companion widget is rendering. Neither command toggles desktop settings or starts recording. Node.js is required only for these tests.

## License

MIT. Workspace code derives from Omarchy. Flat Tray is vendored from [WhiteWebDev/omarchy-flat-tray](https://github.com/WhiteWebDev/omarchy-flat-tray) with its license preserved. See [NOTICE](NOTICE), [LICENSE](LICENSE) and [the tray license](widgets/tray/LICENSE).
