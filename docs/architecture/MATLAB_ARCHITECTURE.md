# MATLAB Architecture

```
matlab/
├── setup_enr312.m                     path set-up — run first
├── functions/+enr312/
│   ├── repoRoot.m, newRunId.m
│   ├── +motor/
│   │   ├── params.m                   every parameter + status + source
│   │   ├── defaultConfig.m            runnable config per plant/loop
│   │   ├── presets.m, presetConfig.m  named experiments (shared by app and batch)
│   │   ├── pidInit.m, pidStep.m       THE controller law (firmware must match)
│   │   ├── simulate.m                 bare motor (exact ZOH) and rig (drive model)
│   │   ├── metrics.m                  rise / overshoot / settling / e_ss / load / verdict
│   │   ├── exportRun.m                simulation evidence folder
│   │   ├── exportHardwareRun.m        raw hardware CSV (read-only) + metadata
│   │   └── HardwareLink.m             serial adapter, protocol v1, PING watchdog
│   └── +protocol/                     encode / parse / checksum / decodeTelemetry / flagNames
├── apps/MotorControlApp/MotorControlApp.m
├── models/dc_motor/                   Simulink builder, runner, generated .slx
├── scripts/motor_formal_runs.m        batch: all presets → evidence, table, figures, videos
└── tests/                             matlab.unittest, 33 tests (1 needs Simulink)
```

## MotorControlApp

Programmatic `uifigure` (no App Designer binary), following the layout of the pendulum lab app
in `odyssix_stm32_core/matlab/experiments/EXP005/exp005_lab.m`: header bar, scrollable control
column with sections and value-labelled sliders, an animated rig view with a status badge and a
teaching caption, live plots, a results table with theory checks, and a yellow "Model limits"
panel that is always visible.

| Area | Content |
|---|---|
| Header | Title; badge **SIMULATION – model, not measured** (blue) or **HARDWARE – live data** (red) |
| Controls | Data source; preset; plant; loop; controller; RUN; playback speed; *Record video*; Export; setpoint, load step and time; Kp/Ki/Kd (units change with plant/loop); Ts and latency; quantisation; motor/drive physics (ESTIMATED); hardware link (port, connect, Start, Stop-hold, E-STOP, status) |
| Centre | Verdict badge, caption, signal-chain diagram (who closes which loop), gear-motor side view, output-disc face with angle pointer, setpoint pointer, motion trail, current, base and output speed, load indicator |
| Right | Output vs setpoint with "what the controller sees" stairs; error; control output with limits; armature current with the 3 A drive limit; the other state (angle or speed) |
| Bottom | Results table + theory prediction; model limits |

Any change re-simulates immediately (≈ 20 ms). RUN replays at real time. Record captures the
window with `getframe` at 15 fps, writes MJPEG AVI, converts to MP4 with ffmpeg, and exports the
run evidence into the same folder.

Hardware mode: a 0.1 s `timer` polls `HardwareLink`, plots measured telemetry over the grey
simulation prediction for the same settings. **Stop and E-STOP send their command first and tidy
up afterwards**, so they do not depend on the plotting timer. Closing the window sends STOP.

## Scripting the app

`app = MotorControlApp()` returns handles: `app.preset(name)`, `app.set(name, value)`,
`app.run()`, `app.export()`, `app.result()`, `app.lastVideo()`.
