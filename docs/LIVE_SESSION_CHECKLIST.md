# Live session checklist (all three rigs)

## Before the session (any computer)

1. `git pull` (or the install line again), then in MATLAB: `enr312_doctor`. Every FAIL has its fix.
2. `enr312_doctor fix` once per computer: installs the Arduino toolchain (about 60 MB).
3. Open each app once without hardware (`enr312_start`, `enr312_start temperature`,
   `enr312_start water`) and press PLAY SIMULATION on one mission.

## At each bench

| Step | DC motor | Temperature | Water level |
|---|---|---|---|
| Safety | battery off while wiring; shaft free | **mains unplugged while wiring**, enclosure closed | tank on a tray, electronics above the water line |
| Wiring | [motor](wiring/DC_MOTOR_WIRING.md) | [temperature](wiring/TEMPERATURE_WIRING.md) | [water](wiring/WATER_LEVEL_WIRING.md) |
| Physics panel | battery voltage (measure it) | bulb W and V, box size, room temperature | tank L×W×H, sensor height, outlet bore, pump flow |
| Plug in the Uno | **Flash + connect** (first time on a board), else Connect | the same; choose the LCD type first | the same |
| Check | DRIVE CHECK: LPR 13, loop ~74.5 ms | SENSOR CHECK: a sensible reading | SENSOR CHECK: the level matches a ruler |
| First run | M1, open loop, small speed | T1 heating curve (or T2 on-off at 35 °C) | W2 on-off 30-80 % |
| Stop | ABORT / Esc / Space / STOP | the same (bulb off) | the same (pump off) |

## During

- Every run is saved and numbered (`data/RUN_REGISTER.csv`), including stopped and aborted runs.
- If the state chip turns red (FAULT), read the message, fix the cause, press CLEAR FAULT.
- RUNS → pick a run → OVERLAY RUN compares it with the simulation of its own settings.

## After

1. **SYNC DATA** in each app (or `git add data results && git commit && git push`): the runs go
   to GitHub. The first push on a computer asks you to sign in; the owner must have added you.
2. Reports: `motor_session_report('YYYY-MM-DD')` for the motor; overlay runs in the other apps.
