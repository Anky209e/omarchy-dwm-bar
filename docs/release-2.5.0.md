DWM Bar 2.5.0 adds an adaptive corner drawer: connections, state toggles, configured add-ons and application tray icons remain accessible while essential status stays visible. Includes Force drawer, keyboard access, theme contrast improvements and individual plugin visibility settings from 2.4.

Install:
```sh
omarchy plugin install https://github.com/Anky209e/omarchy-dwm-bar
```

Validation: parser/layout/contrast checks, 12 Python tests, live dual-output smoke checks, native/Agents/monitor panel routing, Game mode pause/resume, and worker recovery. Tested on Omarchy 4.5.0-3 / Quickshell 0.3.2.

Known limits: physical suspend/hotplug/audio-reconnect/player-switch checks remain manual. Packaged Agents may emit startup callback warnings; its panel is functional. An optional hyprmoncfg 2.7.0 lifecycle patch is supplied separately and is not automatically applied to other plugins.
