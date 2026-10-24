# Water level: tank, DC pump, HC-SR04, relay, Arduino Uno

Course tasks (ENR312 WATER handout): Lmin and Lmax, on-off control through the relay, fill and
drain times, chattering, and the Simulink model with the Relay block of Assignment 3. Every
handout question: [`docs/experiments/water_level/COURSE_QUESTIONS.md`](../docs/experiments/water_level/COURSE_QUESTIONS.md).

## Status (2026-10-24)

| Part | Status |
|---|---|
| Firmware [`firmware/level_controller`](firmware/level_controller) | compiles in CI on Windows, macOS, Linux; end-to-end test against an emulated tank, sensor and relay; **not yet run on the rig** |
| Mission control [`enr312_water`](../matlab/apps/enr312_water/enr312_water.m) | DONE: missions W1-W7 and LAB, physics panel, SIM / RIG / REF table, every rig run recorded |
| Physics | from the tank, the outlet and the pump ([`physics.m`](../matlab/functions/+enr312/+level/physics.m)); values ASSUMED until measured at the bench |
| Simulink [`enr312_water_level.slx`](../matlab/models/water_level) | Relay block, P / PI, open loop; built from the app's settings (OPEN IN SIMULINK) |
| Rig runs | none yet: [`data/RUN_REGISTER.csv`](../data/RUN_REGISTER.csv) will list them as `WATER-R0001_…` |

## Quick start

```matlab
cd <repo>/matlab
enr312_start water
```

Guide: [`docs/guide/WATER.md`](../docs/guide/WATER.md). Measure the tank and the sensor height
first: they set both the model and the firmware's level scale.

## Before any hardware run

Keep the pump supply and the mains away from the water. [`docs/wiring/WATER_LEVEL_WIRING.md`](../docs/wiring/WATER_LEVEL_WIRING.md),
[`docs/safety/EXPERIMENT_CHECKLIST.md`](../docs/safety/EXPERIMENT_CHECKLIST.md). Calibration sheet:
[`calibration_template.csv`](../docs/experiments/water_level/calibration_template.csv).

## Layout

```
water_level/firmware/level_controller/   Arduino sketch (protocol v1, $LTEL telemetry)
water_level/tests/                       the sketch compiled for the PC against an emulated tank
matlab/apps/enr312_water/                mission control
matlab/functions/+enr312/+level/         physics, simulation, cycle analysis, calibration
matlab/models/water_level/               Simulink model and its builder
```
