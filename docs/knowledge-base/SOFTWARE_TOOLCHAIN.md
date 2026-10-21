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

## Arduino toolchain (installed 2026-10-09, isolated)

| Tool | Version | Location |
|---|---|---|
| Arduino CLI | 1.5.1 | `~/Projects/tools/arduino-cli/` — always called through `scripts/setup/acli` |
| AVR core | arduino:avr 1.8.8 | `~/Projects/tools/arduino-enr312/data` |
| Libraries | AltSoftSerial 1.4, DHT sensor library 1.4.7, Adafruit Unified Sensor 1.1.15, LiquidCrystal 1.0.7, LiquidCrystal I2C 1.1.2 | `~/Projects/tools/arduino-enr312/user/libraries` |
| Arduino IDE | 2.3.10 AppImage | `~/Applications/arduino-ide_2.3.10_Linux_64bit.AppImage` (use for the Serial Monitor; compile/upload with `scripts/setup/upload`, which uses the isolated libraries) |
| `RMCS2303drive` vendor library | 1.0 | read for reference only (SRC-012), not installed; our firmware implements Modbus itself |

The isolation (`scripts/setup/arduino-cli.yaml`) keeps these out of `~/.arduino15` and
`~/Arduino`, so other projects on this laptop are unaffected. Serial access: user is in `dialout`.

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
matlab -r "run('matlab/setup_enr312.m'); MotorControlApp"                      # the app
matlab -batch "run('matlab/setup_enr312.m'); motor_formal_runs(true)"          # evidence + videos
```

Product dependencies of the code:

| Code | Needs |
|---|---|
| `matlab/functions/+enr312/**`, `MotorControlApp`, all tests except one | base MATLAB |
| `matlab/models/dc_motor/*simulink*`, `test_simulink_crosscheck` | Simulink (test is *skipped*, not failed, without it) |
