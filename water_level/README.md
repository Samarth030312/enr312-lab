# Water level control — tank, DC pump, HC-SR04, relay, Arduino Uno

Course: SRC-001 p.23 (guideline), Assignment 3 (Simulink, Relay block), lab report p.40.

## Status (2026-10-09)

| Part | Status |
|---|---|
| MATLAB model (tank, pump, ultrasonic sensor, guards) | DONE, tank/pump ASSUMED (course gives none) |
| `WaterLevelApp` (simulation + hardware mode) | DONE; hardware mode not run on a board |
| Simulink model `enr312_water_level.slx` with the **Relay block** (Assignment 3) | DONE; period within 1.6 %, P/PI e_ss identical |
| Firmware `firmware/level_controller` | compiles (31 % RAM); **not run on hardware** |
| Wiring + electrical guidelines | `docs/wiring/WATER_LEVEL_WIRING.md` |
| Experiment plans LEVEL-01…07 | `docs/experiments/water_level/LEVEL_EXPERIMENTS.md` |
| Hardware runs | NOT STARTED |

## Quick start

```bash
matlab -r "run('matlab/setup_enr312.m'); WaterLevelApp"
scripts/setup/upload level /dev/ttyACM0
```

## What the simulations show (ASSUMED tank and pump)

| Case | Result |
|---|---|
| On-off 30–80 % (course) | cycles every ~4 min: fill ~3 min, drain ~1 min, 16 pump starts/h |
| On-off 50–55 % | 184 starts/h — chattering |
| Drain opened 1.2× | pump can only reach 67 %: Lmax unreachable, pump runs continuously |
| P, Kp = 10 / 50 | e_ss 17 % / 3.9 % |
| PI | e_ss ≈ 0, also after the drain step |
