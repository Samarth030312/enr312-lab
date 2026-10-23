# DC motor: RMCS-2303 drive, RMCS-5032 motor, Arduino Uno

Course tasks (ENR312 MOTOR handout): identify the motor, learn the driver, control position
and speed with the Arduino, explore P, I and PI. Traceability:
[`docs/requirements/COURSE_REQUIREMENTS.md`](../docs/requirements/COURSE_REQUIREMENTS.md) §2;
every handout question: [`docs/experiments/dc_motor/COURSE_QUESTIONS.md`](../docs/experiments/dc_motor/COURSE_QUESTIONS.md).

## Status (2026-10-23)

| Part | Status |
|---|---|
| Motor and drive documentation | DONE: [`HARDWARE_REFERENCE.md`](../docs/knowledge-base/HARDWARE_REFERENCE.md) |
| Control-loop boundary | DECIDED: ED-M1 (Arduino P / I / PI around the drive's speed mode) |
| Firmware [`firmware/motor_controller`](firmware/motor_controller) | ON THE RIG since 2026-10-11; host tests against an emulated RMCS-2303 |
| Rig model | IDENTIFIED from the rig's own steps: K 1.000, ramp 53.4 rpm/s, Modbus latency 70 ms ([`rigModel`](../matlab/functions/+enr312/+motor/rigModel.m)) |
| Mission control app [`enr312_motor`](../matlab/apps/enr312_motor/enr312_motor.m) | DONE; end-to-end test against the firmware emulator |
| Course hardware experiments S3-2 … S3-12 | DONE on the rig, 2026-10-23 ([report](../results/reports/dc_motor/2026-10-23/REPORT.md)) |
| Open | runaway stop at the start of run 2 of "S3-2/S3-4" (3 of 3); proposed firmware fix in the report |

## Quick start

```matlab
cd <repo>/matlab
enr312_start                % checks this computer, installs the Arduino toolchain once, opens the app
```

Pick a mission, read the plots and the SIM / RIG / REF table, press PLAY SIMULATION. Plug in
the Uno: the app offers to flash the firmware and connect; then RUN ON RIG. Guide:
[`docs/guide/README.md`](../docs/guide/README.md).

Shell (Linux, macOS), same toolchain: `scripts/setup/upload motor <port>`,
`scripts/validation/build_firmware.sh` (all sketches + host tests).

## The one thing to understand first

The RMCS-2303 is a closed-loop servo drive. It already controls speed with its own internal
loop. "P, I and PI on the Arduino" is therefore an **outer** loop around the drive's speed
mode, running only as fast as 9600-baud Modbus allows (10 Hz, with a 70 ms command latency).
That is why P alone on speed leaves r/(1+Kp) error, why P alone on position already reaches
the target, and why the handout's ζ = 0.7 PI design (no delay in it) overshoots 29 % and then
limit-cycles on the real rig. See [`CONTROL_THEORY.md`](../docs/knowledge-base/CONTROL_THEORY.md) §5.

## Layout

```
dc_motor/firmware/motor_controller/   Arduino sketch (Modbus ASCII to the drive, protocol v1 to MATLAB)
dc_motor/tests/                       the sketch compiled for the PC against an emulated drive
docs/experiments/dc_motor/            plans, course answers, simulation results
results/reports/dc_motor/<date>/      one report per rig session
matlab/apps/enr312_motor/             mission control
matlab/functions/+enr312/+motor/      model, controller, metrics, experiments, serial link
matlab/models/dc_motor/               Simulink: identified and physical models
```

## Before any hardware run

[`docs/safety/EXPERIMENT_CHECKLIST.md`](../docs/safety/EXPERIMENT_CHECKLIST.md) and the wiring in
[`docs/wiring/DC_MOTOR_WIRING.md`](../docs/wiring/DC_MOTOR_WIRING.md).
