# Temperature control — bulb heater, DHT22, SSR-40DA, LCD, Arduino Uno

Course: SRC-001 p.17 (guideline), Assignment 2 (Simulink), lab report p.40.

## Status (2026-10-09)

| Part | Status |
|---|---|
| MATLAB model (thermal + DHT + SSR + controllers) | DONE, parameters ESTIMATED |
| `TemperatureControlApp` (simulation + hardware mode) | DONE; hardware mode not run on a board |
| Simulink model `enr312_temperature.slx` (Assignment 2) | DONE; agrees with MATLAB (≤ 0.14 °C mean) |
| Firmware `firmware/temperature_controller` | compiles (46 % RAM); **not run on hardware** |
| Wiring + electrical guidelines | `docs/wiring/TEMPERATURE_WIRING.md` |
| Experiment plans TEMP-01…07 | `docs/experiments/temperature/TEMP_EXPERIMENTS.md` |
| Hardware runs | NOT STARTED |

## Quick start

```bash
matlab -r "run('matlab/setup_enr312.m'); TemperatureControlApp"
scripts/setup/upload temperature /dev/ttyACM0           # DHT22, parallel LCD
scripts/setup/upload temperature /dev/ttyACM0 -DLCD_I2C -DDHT_KIND=DHT11
```

## What the simulations show (ESTIMATED plant)

| Course task | Result |
|---|---|
| On-off at 35 / 45 / 55 °C | regulates within ~2 °C p-p, ~2.6 switchings/min |
| Moving average N = 10 | **no effect** — 10 × 10 ms = 0.1 s, but the DHT22 only updates every 2 s |
| Moving average N = 500 | fewer switchings, wider band (5 s of lag) |
| P, Kp = 1 / 2 | never reaches the setpoint (e_ss = 15 / 9.6 °C) |
| P, Kp = 50 / 100 | e_ss 1.3 / 0.7 °C, but ~1100 switchings/min: the PWM-into-zero-cross-SSR flicker |
| P, Kp = 500 | behaves like on-off |
| P with time-proportioning | same e_ss as Kp = 50, 20× less flicker |

Theory check shown in the app: e_ss = (SP − T_amb) / (1 + Kp·η·P·R/255).
