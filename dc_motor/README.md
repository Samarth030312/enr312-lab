# DC motor — RMCS-2303 drive + RMCS-5032 motor + Arduino Uno

Course tasks (SRC-001 p.33): identify the motor, learn the driver, control position and speed
with Arduino, explore P, I and PI. Traceability: `docs/requirements/COURSE_REQUIREMENTS.md` §2.

## Status (2026-10-11)

| Part | Status |
|---|---|
| Motor and drive documentation | DONE — `docs/knowledge-base/HARDWARE_REFERENCE.md` |
| Control-loop boundary | DECIDED — ED-M1 (Arduino P/I/PI around the drive's speed mode) |
| MATLAB simulation (rig + bare motor) + Simulink model | DONE, parameters ESTIMATED; Simulink agrees to < 1e-10 |
| `MotorControlApp` (simulation + hardware mode, Drive check, Stop, E-STOP) | DONE |
| Firmware `firmware/motor_controller` | DONE — compiles (49 % flash, 48 % RAM); **runs on the PC against an emulated RMCS-2303: 23/23 checks**; MATLAB parses its whole output |
| Circuit diagram, power diagram, current/fuse/wire requirements | DONE — `docs/wiring/DC_MOTOR_WIRING.md`, `docs/wiring/figures/` |
| Flash + first-run procedure | DONE — `docs/wiring/DC_MOTOR_WIRING.md` §5 |
| Hardware runs MOTOR-01 … 08 | **NOT STARTED — next: flash and follow §5** |

## Quick start

```bash
cd ~/Projects/enr312-lab
scripts/setup/upload motor                 # flash the Uno (Uno on USB, drive unpowered)
matlab -r "run('matlab/setup_enr312.m'); MotorControlApp"
scripts/validation/build_firmware.sh       # compile all firmware + run the PC firmware tests
```

Pick a preset, move sliders, press RUN. Tick "Record video" to save an MP4 + evidence.

```bash
matlab -batch "cd matlab/tests; results = runtests; assertSuccess(results)"
matlab -batch "run('matlab/setup_enr312.m'); motor_formal_runs(true)"
```

## The one thing to understand first

The RMCS-2303 is a closed-loop servo drive. It already controls speed (Mode 1) and position
(Mode 2) with its own internal loop. "P, I and PI on the Arduino" therefore means an **outer**
loop around the drive's speed mode, running only as fast as 9600-baud Modbus allows
(~7–10 Hz). That is why P alone on speed leaves r/(1+Kp) error and rings as Kp → 1, and why
P alone on position already reaches the target. See `docs/knowledge-base/CONTROL_THEORY.md` §5.

## Layout

```
dc_motor/firmware/motor_controller/   Arduino sketch (not yet written)
dc_motor/experiments/                 hardware run notes (none yet)
docs/experiments/dc_motor/            MOTOR-01 … 08 plans and acceptance criteria
matlab/functions/+enr312/+motor/      model, controller, metrics, export, serial link
matlab/apps/MotorControlApp/          the app
matlab/models/dc_motor/               Simulink model + builder
```

## Before any hardware run

`docs/safety/EXPERIMENT_CHECKLIST.md`, then MOTOR-01, then MOTOR-02 (identify the plant and
replace the ESTIMATED parameters).
