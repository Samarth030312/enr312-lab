# System Architecture

## DC-motor path (current focus)

```
                  USB 115200, protocol v1            Modbus ASCII 9600 (SoftwareSerial D2/D3)
 enr312_motor     ───────────────────────  Arduino Uno  ─────────────────────────  RMCS-2303
 (MATLAB)          $CFG $SET $RUN $STOP      outer P/I/PI     reg 14 speed cmd       Mode 1 speed loop
   │               $TEL telemetry            Ts ≈ 0.1–0.15 s  reg 20/22/24 feedback     │  M+/M−
   │                                                                                      ▼
   ├── simulation:  enr312.motor.simulate  (same loop, ESTIMATED plant)          RMCS-5032 12 V
   │                enr312_dc_motor.slx    (bare-motor model, course week 4)     100:1, 5200 cpr
   └── evidence:    results/evidence/… (sim)   data/raw/dc_motor/… (hardware)    encoder → drive
```

Who closes which loop (ED-M1):

| Loop | Where | Rate |
|---|---|---|
| Current / torque | RMCS-2303 (internal, undocumented) | unknown |
| Motor speed | RMCS-2303 Mode 1 (internal PI-like; gains in registers 4–8, effect UNVERIFIED) | unknown |
| **Experiment loop (speed or position, P / I / PI)** | **Arduino** | Modbus-limited, ESTIMATED 7–10 Hz |
| Supervision, plotting, logging | MATLAB | 10 Hz UI timer |

The firmware status: **not written** (`dc_motor/firmware/motor_controller/` is empty).

## Temperature path (not started)

DHT22 → Arduino Uno → structured telemetry → MATLAB application / CSV logger.
The heater command must pass through a verified, appropriately rated switching interface.

## Pneumatic path (not started)

FluidSIM → Circuit 01 / Circuit 02 → saved native model + evidence.

## Separation of concerns

- Firmware: hardware interfacing and device-level operations.
- MATLAB `+enr312/+motor`: model, controller law, metrics, export — no UI, no I/O.
- MATLAB `+enr312/+protocol`: framing only — no knowledge of motors.
- `HardwareLink`: serial I/O only.
- `enr312_motor`: UI only; calls the above.
