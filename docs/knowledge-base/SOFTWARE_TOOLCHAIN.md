# Software Toolchain

State verified on **2026-10-09** on the development laptop (Ubuntu, kernel 6.8, user `odyssix`).
Re-run the checks below and update this file whenever something is installed.

## Installed and verified

| Tool | Version | How verified | Notes |
|---|---|---|---|
| MATLAB | R2026a Update 5 (26.1.0.3346908) | `~/MATLAB/R2026a/VersionInfo.xml`, `ver` | |
| Simulink | 26.1 (R2026a) | `ver('simulink')` | **Installed 2026-10-09** with `mpm` (was licensed, not installed) |
| Control System Toolbox | R2026a | installed with `mpm` the same day | Not used by any code yet; the app and tests are base MATLAB + Simulink |
| Python | 3 (system) | `command -v python3` | Not required by the motor work |
| ffmpeg | system package | `command -v ffmpeg` | Converts the app's AVI recordings to MP4 |
| git, gh | system packages | `command -v` | `gh` authentication not checked |
| pdftotext | poppler-utils | used to extract the manuals | |

Install command that was used:

```bash
~/Projects/matlab-installer/mpm install --release=R2026a \
    --destination=/home/odyssix/MATLAB/R2026a --products Simulink Control_System_Toolbox
```

### MATLAB capability checks (2026-10-09)

| Capability | Result |
|---|---|
| `uifigure` / `uiaxes` with a display (`DISPLAY=:0`) | works |
| `getframe(uifigure)` | works, ≈ 0.27 s per frame |
| `exportapp` | works |
| `VideoWriter` profiles | Motion JPEG AVI, Motion JPEG 2000, Archival, Uncompressed/Grayscale/Indexed AVI — **no MPEG-4 on Linux**, hence ffmpeg |
| `serialport` | present (base MATLAB) |

## Arduino toolchain (pinned, per project, every OS)

Since 2026-10-23 the toolchain is installed and used by MATLAB itself, the same way on
Windows, macOS and Linux (`matlab/functions/+enr312/+tools/`):

| Item | Version | Where it comes from |
|---|---|---|
| Arduino CLI | 1.5.1, SHA-256 checked per platform | downloads.arduino.cc; hashes from the release's `1.5.1-checksums.txt`, pinned in `enr312.tools.manifest` |
| AVR core | arduino:avr 1.8.8 (avr-gcc 7.3.0-atmel3.6.1-arduino7, avrdude 8.0.0-arduino1) | Arduino package index |
| Libraries | AltSoftSerial 1.4, DHT sensor library 1.4.7, Adafruit Unified Sensor 1.1.15, LiquidCrystal 1.0.7, LiquidCrystal I2C 1.1.2 | Arduino library index |

| OS | Tool folder (`enr312.tools.paths`, override with `ENR312_TOOLS`) |
|---|---|
| Windows | `%LOCALAPPDATA%\enr312` (`C:\enr312-tools` if that path is not plain ASCII) |
| macOS | `~/Library/Application Support/enr312` (Apple silicon needs Rosetta 2: avr-gcc and avrdude are x86_64-only builds) |
| Linux | `~/.local/share/enr312`; on this laptop the earlier `~/Projects/tools` is used |

The CLI gets its folders through `ARDUINO_DIRECTORIES_*` environment variables for each call,
so no configuration file with machine paths exists and `~/.arduino15` / `Documents\Arduino`
are never touched. Install or repair: `enr312_doctor fix` in MATLAB. Shell helpers
(`scripts/setup/acli`, `upload`, `arduino-ide`) read the same folders from `scripts/setup/env.sh`.
Verified 2026-10-23 on this laptop by a fresh install into an empty folder (download, hash,
core, libraries) followed by a compile of the motor sketch. The Arduino IDE 2.3.10 AppImage
(`~/Applications/`) is still used for its Serial Monitor on this laptop only.

## Not installed (OPEN)

| Tool | Needed for | Item |
|---|---|---|
| OBS Studio | desktop recordings outside MATLAB (FluidSIM, hardware) | OI-E3 |
| FluidSIM | pneumatic simulations | not started |

Arduino CLI install (user-level, no sudo), per the official instructions:

```bash
mkdir -p ~/Projects/tools/arduino-cli
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
    | BINDIR="$HOME/Projects/tools/arduino-cli" sh
~/Projects/tools/arduino-cli/arduino-cli core update-index
~/Projects/tools/arduino-cli/arduino-cli core install arduino:avr
```

## Running the MATLAB code

```bash
cd ~/Projects/enr312-lab
matlab -batch "cd matlab/tests; results = runtests; assertSuccess(results)"    # 31 tests
matlab -r "cd('matlab'); enr312_start"                      # the app
matlab -batch "run('matlab/setup_enr312.m'); motor_formal_runs(true)"          # evidence + videos
```

Product dependencies of the code:

| Code | Needs |
|---|---|
| `matlab/functions/+enr312/**`, `enr312_motor`, all tests except the Simulink ones | base MATLAB |
| `matlab/models/dc_motor/*simulink*`, `test_simulink_crosscheck` | Simulink (test is *skipped*, not failed, without it) |
