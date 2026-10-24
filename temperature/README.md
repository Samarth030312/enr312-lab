# Temperature: bulb heater, DHT11, solid-state relay, LCD, Arduino Uno

Course tasks (ENR312 TEMP handout): on-off control at 35, 45 and 55 °C, hysteresis, a moving
average, P control and the Simulink model of Assignment 3. Every handout question:
[`docs/experiments/temperature/COURSE_QUESTIONS.md`](../docs/experiments/temperature/COURSE_QUESTIONS.md).

## Status (2026-10-24)

| Part | Status |
|---|---|
| Firmware [`firmware/temperature_controller`](firmware/temperature_controller) | compiles in CI on Windows, macOS, Linux; end-to-end test against an emulated DHT11, relay and box; **not yet run on the rig** |
| Mission control [`enr312_temp`](../matlab/apps/enr312_temp/enr312_temp.m) | DONE: missions T1-T8 and LAB, physics panel, SIM / RIG / REF table, every rig run recorded |
| Physics | from the bulb, the box and the room ([`physics.m`](../matlab/functions/+enr312/+temperature/physics.m)); values ASSUMED until measured at the bench |
| Simulink [`enr312_temperature.slx`](../matlab/models/temperature) | built from the app's settings (OPEN IN SIMULINK) |
| Rig runs | none yet: [`data/RUN_REGISTER.csv`](../data/RUN_REGISTER.csv) will list them as `TEMP-R0001_…` |

## Quick start

```matlab
cd <repo>/matlab
enr312_start temperature
```

Guide: [`docs/guide/TEMPERATURE.md`](../docs/guide/TEMPERATURE.md). Before the first rig run, type
the bulb, box and room values into the physics panel and choose the LCD type (parallel or I2C).

## Before any hardware run

The bulb runs on mains. [`docs/wiring/TEMPERATURE_WIRING.md`](../docs/wiring/TEMPERATURE_WIRING.md),
[`docs/safety/EXPERIMENT_CHECKLIST.md`](../docs/safety/EXPERIMENT_CHECKLIST.md).

## Layout

```
temperature/firmware/temperature_controller/   Arduino sketch (protocol v1, $TTEL telemetry)
temperature/examples/lcd_hello_alignment/      the handout's LCD exercise
temperature/tests/                             the sketch compiled for the PC (moving average, emulator)
matlab/apps/enr312_temp/                       mission control
matlab/functions/+enr312/+temperature/         physics, simulation, fit
matlab/models/temperature/                     Simulink model and its builder
```
