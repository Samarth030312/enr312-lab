# Changelog

## 2026-10-24: all three rigs, physics from the real parts, one run register

* **Temperature (`enr312_temp`) and water level (`enr312_water`)** mission controls, on a shared
  engine (`enr312.ui.missionControl`): missions for the TEMP and WATER handouts and Assignment 3,
  a 3-D scene each (glowing bulb, DHT11, SSR, LCD; tank with water column, pump, flows, HC-SR04,
  valve), SIM / RIG / REF tables with theory from the physics, OPEN IN SIMULINK, rig runs saved
  and registered, end-to-end tests against real-time firmware emulators.
* **Physics from what is on the bench:** `enr312.motor.physics` (datasheet → R, Kt, b, τe, τm,
  ω(s)/V(s); free speed 168 rpm at 11.2 V, as measured), `enr312.temperature.physics` (bulb W and V,
  box, wall loss, sensor → K, τ, θ), `enr312.level.physics` (tank, outlet bore and Cd, valve, pump
  curve → Torricelli k, steady levels, linearised K, τ).
* **DC motor:** the 3-D rig to the RMCS-5032 drawing, the RMCS-2303 board and the Uno outline;
  PLANT choice (identified rig, drive physics, bare armature), PID, load-torque step, inertia
  factor, armature current, battery runtime, mission M10.
* **Simulation:** temperature PID, open loop, power limit with or without anti-windup, ambient
  step; water open loop, pump curve, spill, guards switchable; Simulink models for both extended
  to match (temperature PI/PID, saturation, ambient step; water open loop).
* **Run register:** every rig run of any apparatus is `<APP>-R<nnnn>_<time>_<mission>` in
  `data/RUN_REGISTER.csv`, with rig, firmware, port, settings and result; stopped and aborted runs
  are kept; the 61 motor runs were renamed (old ids still resolve). **SYNC DATA** pushes new runs.
* `enr312.ident.fitThermal`: K, τ, θ from heating and cooling together.
* Fix: frames of a previous run or idle frames arriving after RUN no longer end a new run.

## 2026-10-23: mission control, every operating system, the course on the rig

**DC-motor mission control (`enr312_motor`)** replaces MotorControlApp.
* Missions M1-M9 follow the MOTOR handout; LAB is free use. Each mission's presets are the runs
  of its course hardware experiment, so simulation and rig run the same thing.
* The rig in 3-D: the output disc turns with the simulated, live or recorded angle; a speed
  ring, the setpoint tick and a motion wedge track the movement.
* Two plots (controlled variable, command), plus the static map in M2. A SIM / RIG / REF table,
  scored for all three by one function (`enr312.motor.stepMetrics`).
* The simulation is the Arduino's loop around the rig identified from its own steps
  (`enr312.motor.rigModel`); REF is the course's first-order model.
* Rig: plug-in detection, FLASH FIRMWARE on any OS, DRIVE CHECK, RUN ON RIG (one run or the whole
  series), LIVE SETPOINT, ABORT (Esc / Space), firmware faults explained, CLEAR FAULT; every run
  saved automatically; RUNS lists, overlays and replays any recorded run; IDENTIFY re-fits the
  model from one run.
* Tests: `test_motor_app` (headless) and `e2e_motor_mission_control` (the app against the firmware
  emulator: 19 checks).

**Windows, macOS, Linux.**
* `install/`: one line per system (cmd, PowerShell, Terminal) that fetches the repository, checks
  the USB driver and starts the lab.
* `enr312_start` and `enr312_doctor`: the computer is checked (MATLAB, path, git, toolchain,
  Rosetta 2, CH340 / FTDI drivers, serial permission, busy ports) and every problem comes with
  its fix.
* `enr312.tools`: the Arduino toolchain pinned by version and SHA-256, installed and run from
  MATLAB on every OS, in a project folder (no global Arduino state, no machine paths).
* Port discovery for COM ports, macOS `/dev/cu.*` (never the blocking `tty.*`) and Linux.
* CI on Windows, macOS and Ubuntu: installer, toolchain, firmware build, MATLAB tests; Linux
  also runs the end-to-end test. A job on R2023b checks the oldest supported MATLAB.
* Recordings: native MPEG-4 on Windows and macOS (ffmpeg only on Linux).

**The course on the rig.** 38 runs of the course experiments (S3-2, 3, 5, 9, 10, 12) and their
report (`results/reports/dc_motor/2026-10-23/`, `matlab/scripts/motor_session_report.m`). The
course answers are updated to DONE-HW. Open: OI-M12, a full-speed reverse start at RUN caught
by the runaway guard.

**Repository.** MIT licence, third-party notice, line-ending rules, a front page and a guide.

## 2026-10-21: all three experiments in simulation

DC motor identified from its own steps; answers to the MOTOR, TEMP and WATER handouts in
simulation; temperature and water-level firmware tested on the PC against emulated hardware.

## 2026-10-11: the motor firmware on the rig

RMCS-2303 Modbus firmware with runaway guard, first rig session (20 runs), incident report.
