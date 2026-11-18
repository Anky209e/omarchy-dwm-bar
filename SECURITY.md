# Security scope

This plugin runs inside Omarchy's unsandboxed desktop shell. Manifest validation and passing tests are not an independent security audit or a guarantee of approval.

- No root privileges or permission relaxation are requested.
- Hardware discovery uses PCI sysfs. GPU monitoring checks the selected device's runtime power state before accessing sensors.
- Executed programs use argument arrays and fixed command choices. Configuration and player metadata are never executed as shell commands.
- Remote artwork is disabled by default, opt-in, HTTPS-only and restricted to documented hosts and bounded PNG/JPEG images. Player metadata is rendered as plain text.
- Local artwork must be a regular non-symlink file. Named pipes and devices are rejected without blocking. Cached images are bounded and revalidated before use.
- Settings are normalized and written atomically. The dependency doctor is read-only and does not access the network or install packages.
- CI has read-only repository permissions and pins its checkout action to an immutable revision; checkout credentials are not persisted.

Regression tests exercise malformed metadata and URLs, sensor bounds, special files, remote-cover consent, redirects and preference validation. A full audit must also review the host shell, Qt image decoders and optional installed plugins. Report a reproducible security issue privately to the repository owner before posting sensitive details publicly. No independent security assessment has been completed.
