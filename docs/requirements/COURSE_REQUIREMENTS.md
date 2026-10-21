# Course Requirements and Traceability

Source: **SRC-001** (ENR312 course file, Monsoon 2025-26). Page numbers are the PDF's printed
"n / 60" numbers. The pendulum experiment is handled in another repository.

## 1. Requirements that apply to every experiment

| ID | Requirement | Source |
|---|---|---|
| R-GEN-1 | Simulate the experiment in MATLAB/Simulink before/alongside hardware | Assignments, p.14 |
| R-GEN-2 | Report with screenshots of simulation inputs and corresponding outputs | Assignments, p.14 |
| R-GEN-3 | Lab report: summary of tasks, detailed description, programs, conclusions (student-wise) | p.42 |
| R-GEN-4 | Answer the Section 2 questions in detail | p.42 |
| R-GEN-5 | Compare real DC-motor position/speed with simulation; advantages/disadvantages of simulation | Outline week 11, p.8 |

## 2. DC motor — traceability

| Req | Course text | Implementation | Verification | Evidence | Status |
|---|---|---|---|---|---|
| R-M1 | "Identify the DC geared motor and note down its specifications" (p.33 task 1) | `HARDWARE_REFERENCE.md` §1; `params.m` | Datasheet cross-checks: `testDatasheetConsistency` | HARDWARE_REFERENCE §1; MOTOR-01 record (pending inspection) | Datasheet DONE; physical label check PENDING |
| R-M2 | "Go through the motor driver specification sheet and learn how to drive motor" (task 2) | `HARDWARE_REFERENCE.md` §2 (modes, registers, wiring, scaling) | Review; MOTOR-01 parameter read-back | MOTOR-01 | Manual DONE; drive read-back PENDING |
| R-M3 | "Use Arduino to control the motor 1) position, and 2) speed" (task 3) | ED-M1; protocol v1; `HardwareLink`; `dc_motor/firmware/motor_controller` (compiles) | MOTOR-03, MOTOR-04 | `data/raw/dc_motor/` | Simulation DONE; firmware DONE (untested on hardware); hardware NOT STARTED |
| R-M4 | "Apply various functions available … Explore P, I and PI" (task 4) | `pidStep.m`; presets per controller; ED-M1 option A for drive gains | MOTOR-05/06/07; unit tests | figures `rig_speed_P_I_PI.png`, `rig_position_P_I_PI.png`; metrics table | Simulation DONE; hardware NOT STARTED |
| R-M5 | Simulink DC motor model; components and constants specific to that motor (week 4, p.8) | `enr312_dc_motor.slx` built by `build_dc_motor_simulink.m` | `test_simulink_crosscheck` (< 1e-10 vs MATLAB) | `results/figures/dc_motor/simulink_*.png` | DONE (parameters ESTIMATED) |
| R-M6 | Open-loop and closed-loop, effect of disturbance in open loop (week 4) | Presets "Bare motor … + load", load slider | `testIntegralActionRemovesError` | `bare_speed_disturbance.png` | DONE |
| R-M7 | Position and speed control simulation; study governing parameters (week 4) | App sliders: gains, Ts, latency, J, R, drive bandwidth, ramp | Live in app; sweeps | `rig_speed_P_steady_state_error.png` | DONE |
| R-M8 | Assignment 5: realistic simulation, screenshots of inputs/outputs, impress the TA (p.14) | `MotorControlApp` (animated rig + live plots + recording) | Screenshots, recordings | `results/evidence/simulation_runs/dc_motor/*/simulation.mp4` | DONE (simulation) |
| R-M9 | Real DC motor open/closed-loop PID implementation (week 5) | Firmware + hardware mode of the app | MOTOR-03 … 07 | | NOT STARTED |
| R-M10 | Compare real vs simulated position/speed (week 11) | Hardware mode overlays the simulation prediction; MOTOR-08 | MOTOR-08 | | NOT STARTED |
| R-M11 | Answer Section 2 questions 1–10 (p.34) | `docs/experiments/dc_motor/COURSE_QUESTIONS.md` | Review | | DONE (reference answers for this rig) |
| R-M12 | MOTOR handout Section 3, S3-1 … S3-12 (SRC-013) | `motor_course_questions.m`, `enr312_motor_identified.slx`, "Course S3-x" hardware experiments | `test_motor_identified`, firmware host test | `COURSE_SIM_RESULTS.md` | SIM/analysis DONE; 6 hardware runs PENDING |

## 3. Conflicts between the course text and the hardware

C-M1: the course week-5 parts list (6/9 V battery, diode, MOSFET) describes a generic DC motor;
the lab hardware is an RMCS-2303 servo drive with a 12 V RMCS-5032. We follow the hardware and
reproduce the course's set-up in simulation. Full list: `../knowledge-base/OPEN_ITEMS.md`.

## 4. Temperature — traceability (SRC-001 p.17, Assignment 2)

| Req | Course text | Implementation | Verification | Status |
|---|---|---|---|---|
| R-T1 | Collect Uno, DHT11, bulb, SSR, LCD (task 1) | DHT22 used (C-T1); `docs/wiring/TEMPERATURE_WIRING.md` | inspection | wiring DOCUMENTED; parts not inspected |
| R-T2 | Install the latest Arduino IDE (task 2) | Arduino IDE 2.3.10 AppImage + isolated arduino-cli 1.5.1 | `SOFTWARE_TOOLCHAIN.md` | DONE |
| R-T3 | Read the sensor (task 3) | firmware DHT read every 1/2 s; `$TTEL`; LCD | TEMP-01 | firmware DONE |
| R-T4 | On-off control, flicker, ways to reduce it (task 4) | modes ONOFF, HYST, MA, TPROP | sim + `test_temperature_model` | SIM-DONE |
| R-T5 | Moving average, Ts 0.01 s, N = 10 and 500 (task 5) | run-length MA in firmware (proven equal to ring buffer), MA in model | host test + sim | SIM-DONE |
| R-T6 | Display error; P with Kp 1/2/50/100/500, 0..255 on pin 9; Serial Monitor (task 6) | mode P, LCD line 2, `$TTEL` err/u | `testPSteadyStateErrorMatchesTheory` | SIM-DONE |
| R-T7 | Simulink simulation, screenshots of inputs/outputs (Assignment 2) | `enr312_temperature.slx` | `test_simulink_temperature_level` | DONE |
| R-T8 | Section 2 questions 1–25 | — | — | NOT STARTED |

## 5. Water level — traceability (SRC-001 p.23, Assignment 3)

| Req | Course text | Implementation | Verification | Status |
|---|---|---|---|---|
| R-L1 | Identify Lmin / Lmax (task 1) | 30 % / 80 % defaults, adjustable | — | DONE |
| R-L2 | Tank, DC pump, sensors, relay module (task 2) | HC-SR04 + relay (+ optional MOSFET), `docs/wiring/WATER_LEVEL_WIRING.md` | LEVEL-02 calibration | DOCUMENTED |
| R-L3 | ON-OFF program (task 3) | `water_level/firmware/level_controller` ONOFF | sim, LEVEL-03 | firmware DONE |
| R-L4 | Test cycles, record fill time, switching frequency, chattering (tasks 4–5) | `WaterLevelApp` metrics | `test_level_model` | SIM-DONE |
| R-L5 | Simulink tank model, Relay block, Lmin 30 / Lmax 80, plot level (task 6) | `enr312_water_level.slx` | `test_simulink_temperature_level` | DONE |
| R-L6 | Compare hardware and Simulink (task 7) | hardware mode overlays the prediction | LEVEL-06 | NOT STARTED (hardware) |
| R-L7 | Questions 1–25 (P/I/D, windup, noise) | P / PI modes, clamping anti-windup | sim | SIM-DONE; answers NOT STARTED |

## 6. Pneumatic — traceability (SRC-001 p.27, Assignment 4)

Simulation tool: **Festo FluidSIM only** (owner decision, 2026-10-09). Plan: `pneumatic/README.md`.

| Req | Course text | Implementation | Status |
|---|---|---|---|
| R-P1 | Understand the edge-folding circuit (task 1) | component table, conflict C-P1 | DONE |
| R-P2 | Simulate (Assignment 4) | FluidSIM circuits 01 / 02 (`pneumatic/fluidsim/*/BUILD.md`) | BLOCKED on FluidSIM account (student) |
| R-P3 | Tasks 3–9 (two-hand AND, stroke times, gauges, throttle) | PNEU-01 … 05 | NOT STARTED |
