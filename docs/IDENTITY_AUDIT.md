# Identity and protocol audit

## Decision

Extended Name Reflector uses two identities:

- **Protocol ID**: the XLXD-compatible identity passed to the daemon and placed on protocol wire formats. It remains `XLX` plus three alphanumeric characters (six characters total), preserving current XLXD behavior.
- **Extended Name**: a human-readable name used by the installer, dashboard title/comment, local configuration and status output. It is never copied into a fixed-width protocol callsign field.

## Why the identities must remain separate

The audited XLXD source defines `CALLSIGN_LEN` as 8. XLX, DExtra and DCS handlers explicitly read/write fixed-width callsign fields. Changing that shared type would alter packet layouts and risks interoperability. The XLX handler also patches the reflector callsign with the `XLX` prefix.

Therefore this project does **not** enlarge `CCallsign` or any on-wire field.

## Runtime controls

The source already exposes compile-time `ENABLE_*` switches in `src/main.h` for DExtra, DPlus, DCS, XLX, DMRPlus, DMRMMDVM, YSF, G3 and IMRS. The working installer uses those switches rather than maintaining a second protocol-selection mechanism.

Ports are configured by changing the corresponding constants in `src/main.h` before compilation. The transcoder/AMBE endpoint uses `TRANSCODER_PORT`.

## Safety boundary

This repository is independent. Nothing in this project modifies XLX480 or X80. The original imported installer remains at `baseline/installer.sh` and is not edited.
