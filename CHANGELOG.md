# Changelog

## 2.6.2

- Fix local artwork disclosure: owner-only cache directory and atomically written owner-only files, independent of umask.
- Repair legacy image/temporary permissions at worker startup and before reuse. Reject unsafe cache symlinks and fail closed on permission errors.
- Add regressions for private local covers with remote art disabled, legacy cache hits, startup repair and symlink rejection.

## 2.6.1

- Share one theme watcher and lazily build music, settings and drawer contents.
- Stop unused sensor polling without changing visible update rates.
- Cancel queued cover work on close and avoid duplicate cover reloads.
- Close inherited graphics descriptors in the Python worker.
- Add resource cleanup and polling-demand regressions.

## 2.6.0

- Remove the music underline, including the host panel mark.
- Add AMD sysfs utilization, exposed AMD/Intel GPU temperatures and independent missing-sensor handling.
- Select NVIDIA by checked PCI address and preserve discrete GPU sleep protection.
- Detect optional monitor tools, provide fallbacks and show capability diagnostics.
- Reject blocking/non-regular artwork files and validate cached images.
- Add read-only installation diagnostics, portable CI and explicit security/compatibility limits.

## 2.5.0

- Add a per-output adaptive corner drawer with wrapped tray icons and scrolling.
- Keep native and configured plugin panels accessible while their bar icons are collapsed.
- Add Force drawer and focused-output control IPC.
- Add opt-in desktop smoke checks, screenshots, verified compatibility and documented remaining hardware checks.
- Include an optional hyprmoncfg 2.7.0 lifecycle patch; document native Agents startup warnings.

## 2.4.0

- Add visible active markers and readable theme-derived sensor colors.
- Add keyboard focus to music/settings buttons and Escape dismissal.
- Add per-plugin visibility and an appearance reset that preserves display profiles and cover consent.
- Adapt music width per display and document release checks, update and rollback.

## 2.3.2

- Restore configured Agents and monitor widgets in the corner group.
