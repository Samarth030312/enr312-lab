# Simulation and Experiment Evidence

## Evidence policy

Every formal simulation run has: unique run ID, full configuration, software versions, git
revision and dirty flag, parameters with status, raw output data, metrics summary, figure, and a
video when required. Every physical run also records the hardware configuration, safety checks,
and is marked HARDWARE.

## Where things go

| What | Path | In git? |
|---|---|---|
| Simulation run | `results/evidence/simulation_runs/dc_motor/<run_id>/` — `trace.csv`, `samples.csv`, `run_config.json`, `summary.md`, `figure.png`, `simulation.mp4` | ignored (regenerable; videos large) |
| Comparison figures | `results/figures/dc_motor/*.png` | ignored by default; copy chosen ones into the report |
| Metrics table | `results/tables/dc_motor_simulation_metrics.csv` | ignored |
| Hardware raw data | `data/raw/dc_motor/<run_id>.csv` (read-only) | ignored by default — commit deliberately, per DATA_MANAGEMENT §1 |
| Hardware metadata | `data/metadata/dc_motor/<run_id>.json` | commit |
| Hardware video / photos | `results/evidence/hardware_videos/dc_motor/<run_id>/` | ignored; record link in metadata |
| Desktop recordings (FluidSIM, OBS) | `results/evidence/simulation_videos/<subsystem>/<run_id>/` | ignored |

Run IDs: `<EXPERIMENT>-SIM-<yyyyMMdd-HHmmss>[-n]` or `…-HW-…`. Never reused (`newRunId.m`).

## Recording workflow — MATLAB simulations

Built into the app; no OBS needed.

1. Choose the preset / settings. Tick **Record video of RUN + save evidence**. Press RUN.
2. The app captures its own window frame by frame (slower than real time; the video plays at
   real time), writes MJPEG AVI, converts to H.264 MP4 with ffmpeg, exports the run evidence and
   writes the video's file name, size and capture method into `run_config.json`.
3. Batch: `motor_formal_runs(true)` records the key presets.

What the video is: the app's own rendering of the simulation, captured while it ran. It is not a
recording of the desktop, and not of hardware.

## Recording workflow — hardware and other applications

Use OBS (not yet installed, OI-E3) or a phone video. Start recording before the run; stop after
the final plots are visible; save under the run ID; verify the file opens; write its name in the
run metadata. A run is not "recorded" unless that file exists.
