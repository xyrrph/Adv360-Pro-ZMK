# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a **ZMK firmware configuration** repo for the Kinesis Advantage 360 Pro split keyboard — not application source code. It holds keymap/board config that gets built against a custom ZMK fork (pulled in at build time via `west`), producing `.uf2` firmware files to flash onto the keyboard halves.

## Build commands

Requires Podman or Docker (Podman preferred if both present) and `make`.

- `make` / `make all-legacy` — build **Legacy** (non-Clique/non-Studio) firmware, both halves
- `make left-legacy` — Legacy firmware, left half only
- `make all` — build **Clique/ZMK Studio** firmware, both halves
- `make left` — Clique firmware, left half only
- `make clean_firmware` — remove built `.uf2` files from `firmware/`
- `make clean_image` — remove the built docker/podman image (`zmk`)
- `make clean` — both of the above

Output firmware lands in `firmware/` as `<timestamp>-<commit>[-clique][-legacy]-{left,right}.uf2` (gitignored; only `firmware/.gitkeep` is tracked). There is no separate lint/test suite — "correctness" is verified by the ZMK/Zephyr build succeeding (west build) and by flashing/trying the keymap on hardware.

CI (`.github/workflows/build.yml`) builds both variants (`firmware-no-clique` and `firmware-clique`) on every push/PR via `west init/update/build`, mirroring what `Dockerfile` + `bin/build.sh` do locally.

The Makefile regenerates `config/version.dtsi` (via `bin/get_version_local.sh`) before each build and runs `git checkout config/version.dtsi` after — this file is a build-time artifact encoding the timestamp/branch/commit as a macro (`Mod+V` types it out on the keyboard) and should not be hand-edited or committed with local values.

## Key architecture / gotchas

**Single source of truth for the keymap:** `config/adv360.keymap` contains all layer definitions and custom behaviors. `config/adv360_left.keymap` and `config/adv360_right.keymap` are just one-line `#include "adv360.keymap"` wrappers — always edit `adv360.keymap`, never the left/right files.

**`config/keymap.json` must be kept in sync manually.** It's a parallel representation of the same keymap (layer/behavior arrays) used by GUI tools (Nick Coutsos's keymap editor, Kinesis Clique). It is *not* generated from `adv360.keymap` — after changing `adv360.keymap`, port the same change into `keymap.json` by hand (see recent commit history for examples of this pattern, e.g. `b13a2f4`). See `UPGRADE.md` for the exact formatting rules if resolving conflicts here (comma/quote placement per key).

**ZMK source isn't in this repo.** `config/west.yml` points `west` at a Kinesis-customized ZMK fork (`refil/zmk`, branch `adv360-z3.5-2`), not upstream `zmkfirmware/zmk`. Some upstream ZMK docs/features (RGB underglow, backlight, power management sections) don't apply to this fork; consult `README.md`'s "Note" section before assuming upstream ZMK docs are accurate here.

**Clique/Studio vs. Legacy build is a critical, easy-to-misunderstand distinction** (fully detailed in `docs/zmk_clique_vs_legacy_guide.md`, Japanese):
- Clique/Studio build (`CONFIG_ZMK_STUDIO=y`, `make all`/`make left`) stores the keymap in the keyboard's onboard NVS memory, which takes priority at boot over whatever is in the flashed `.uf2`. Once any Clique-enabled firmware has booted (or GUI edits have been saved), **reflashing new firmware built from updated code will silently have no effect** until NVS is cleared.
- Legacy build (`make`/`make all-legacy`) always boots from the code in the flashed `.uf2` and ignores NVS.
- To make code changes take effect again after Clique/Studio use: flash `settings-reset.uf2` to both halves, then flash the desired firmware **directly** — do not flash any intermediate/other firmware in between (even briefly), or that firmware's keymap becomes the new NVS default.
- Reserved/placeholder layers in `adv360.keymap` must be defined with full `&trans`-filled bindings, not `status = "reserved";` — a `"reserved"` layer gets stripped entirely from Legacy builds, shifting every subsequent layer's index and desyncing hardcoded `#define L_*` layer numbers from what's actually built (symptom: a layer's LED indicator changes but all keys behave as `&trans`).

**Custom hold-tap behaviors:** `adv360.keymap` defines `&hm` (homerow_mods, `tap-preferred` flavor with `quick_tap_ms`) alongside stock `&mt` (`hold-preferred`, no quick-tap). Use `&hm` for alpha keys on the home row (rolling/fast typing needs tap-preferred to avoid spurious mod activation); use `&mt` for isolated keys like thumb Space/Shift where tap/hold roles are unambiguous. Full rationale in `docs/zmk_hm_vs_mt.md`.

**Layer numbering:** layers are `#define`d in `adv360.keymap` (`L_BASE`, `L_QWERTY_CUSTOM`, `L_QWERTY_ORIG`, `L_KP`, `L_FN`, `L_EXTRA1`, `L_EXTRA2`, `L_MOD`) and must stay index-aligned with both the `keymap` node order in `adv360.keymap` and the `layer_names`/`layers` arrays in `keymap.json`.

**Board-level config** lives in `config/boards/arm/adv360/`, split per-half (`adv360_left_defconfig`, `adv360_right_defconfig`). Some settings must be mirrored to both files to take effect symmetrically (e.g. `CONFIG_ZMK_RGB_UNDERGLOW_MOD_COLOR`). Notable flags: `CONFIG_ZMK_HID_KEYBOARD_EXTENDED_REPORT` (F13-F24/INTL1-9 support), `CONFIG_BT_BAS` (BLE battery reporting, off by default to avoid spurious host wake-ups).

## Flashing

Flash order matters for split halves: left half → bootloader mode (Mod+macro1) → drop `left.uf2` → power off both → power on left → connect right → bootloader mode (Mod+macro3) → drop `right.uf2`. Full procedure in `README.md`. If either half retains stale NVS settings while the other is reset, connecting them re-syncs the stale settings onto the freshly-reset half — always settings-reset and reflash both halves together.
