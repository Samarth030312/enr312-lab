# DC motor — wiring and electrical guidelines

Hardware: Arduino Uno, Robokits **RMCS-2303** drive, Robokits **RMCS-5032** motor (the pair
supplied together), 12 V DC supply. Firmware: `dc_motor/firmware/motor_controller/`.
Status: wired and powered 2026-10-11. **Encoder colours corrected the same day** (red → pin 11,
orange → pin 10) after a runaway; all other connections verified working (Modbus, slave id 7).

## 1. Pin plan

| Arduino Uno | Connects to | Why |
|---|---|---|
| **D8** (AltSoftSerial RX) | drive **TXD, pin 3** | Modbus replies from the drive |
| **D9** (AltSoftSerial TX) | drive **RXD, pin 2** | Modbus commands to the drive |
| **GND** | drive **GND, pin 1** | common logic reference — mandatory |
| **D4** | STOP push-button (normally open) → GND | hardware E-stop request (internal pull-up) |
| D13 | on-board LED | lit while the loop runs |
| USB | laptop | power for the Uno + MATLAB link (115200 baud) |

**Deviation from the vendor wiring (D2/D3):** the vendor example uses SoftwareSerial on D2/D3.
SoftwareSerial switches interrupts off for ~1 ms per byte, which corrupts commands from MATLAB
arriving at 115200 baud — including STOP. AltSoftSerial keeps interrupts on but is fixed to D8/D9
on the Uno. (D10 cannot be used for PWM while AltSoftSerial is active.)

| Drive pin | Connects to | Wire colour (motor) |
|---|---|---|
| 8 GND | motor encoder GND | **Black** |
| 9 +5 V | motor encoder VCC | **Brown** |
| 10 ENC_B | motor encoder B | **Orange** (EncB on the RMCS-5032 sheet) |
| 11 ENC_A | motor encoder A | **Red** (EncA on the RMCS-5032 sheet) |
| 14 Motor− | motor | **Yellow** |
| 15 Motor+ | motor | **Green** |
| 16 VDD | supply **+12 V** | red supply lead |
| 17 GND | supply **0 V** | black supply lead |

**Correction 2026-10-11 (conflict C-M3).** The drive manual's p.5 diagram is drawn for a
*generic* Rhino motor (red = ENC_B, orange = ENC_A). The **RMCS-5032's own sheet** (SRC-003) says
**red = EncA, orange = EncB**, and the actual part's datasheet wins. The first version of this
guide followed the drive manual; on the rig that crossed A/B and the drive's loops ran away
(`docs/safety/INCIDENT_2026-10-11.md`). The table above is the corrected mapping.
**Wire by pin number on the drive silkscreen, never by the row alignment of the manual's p.5
tables** (conflict C-M4).

## 2. Diagram

```
                 USB (laptop)
                     |
              +-------------+                      +------------------------------+
              | Arduino Uno |                      |        RMCS-2303 drive       |
              |          D9 |-------------------->| 2 RXD                        |
              |          D8 |<--------------------| 3 TXD                        |
              |         GND |---------------------| 1 GND                        |
              |          D4 |---[STOP]---GND       |                              |
              +-------------+                      | 8 GND  ---- black  ---+      |
                                                    | 9 +5V  ---- brown  ---+      |
   12 V supply  (+) --- fuse 5 A T ---- switch -----| 16 VDD                |      |
                (-) --------------------------------| 17 GND        encoder|  RMCS-5032
                                                    | 10 ENC_B --- orange---+  motor
                                                    | 11 ENC_A --- red   ---+  (1:100)
                                                    | 14 M-   ---- yellow ---+
                                                    | 15 M+   ---- green  ---+
                                                    | JP1-JP3: leave open -> ID 11
                                                    +------------------------------+
```

## 3. Power and current requirements

![Power diagram](figures/dc_motor_power.png)

Circuit diagram: [`figures/dc_motor_circuit.png`](figures/dc_motor_circuit.png) (SVG alongside; regenerate with
`python3 scripts/reports/draw_dc_motor_diagrams.py`).

| Item | Requirement | Basis |
|---|---|---|
| Supply voltage | **12 V DC** (11–13 V) | Motor nominal 12 V (SRC-003). Drive accepts 10–30 V (SRC-002 p.4), but 24 V lets it over-speed the motor (C-M6). |
| Supply capacity | **≥ 5 A (60 W)** adapter, or a bench PSU at 12.0 V with **current limit 4 A** | Drive limits phase current to 3 A peak (SRC-002 p.4) → ≤ 36 W; margin for start-up and drive electronics |
| Fuse | **5 A slow-blow (T)** in the + lead | Protects the 0.75 mm² leads. The drive's product page calls it a "10 A" drive while the manual says 3 A peak (C-M7), so do not rely on the drive's limit for wire protection |
| Motor current, free running | 0.4–0.8 A | 0.8 A at full speed (SRC-003); model ≈ 0.45 A at 100 rpm output (ESTIMATED) |
| Motor current at rated load (15 kgf·cm) | ≈ 3 A — **the drive's limit** | ESTIMATED from the datasheet torque constant; usable torque through this drive ≈ 17 kgf·cm |
| Motor stall current | up to 7.5 A (SRC-003) | not reachable through the drive; never hold the shaft at full command |
| Uno | 5 V from USB, ≈ 50 mA | never connected to the 12 V rail |
| Encoder | 5 V from drive pin 9 (tens of mA, UNVERIFIED) | |
| Power wiring | 0.75 mm² (18 AWG), short | supply ↔ drive pins 16/17 and drive ↔ motor pins 14/15 |
| Signal wiring | jumper wires < 30 cm, away from the motor leads | D8, D9, GND |

Grounding: the Uno's GND joins the drive at **pin 1 only**. That is the single common
reference for the UART. Do not run a second ground wire from the Uno to the supply's 0 V.

Drive logic level: the vendor wires the drive directly to a 5 V Uno. If you have a
multimeter, measure drive pin 3 (TXD) to pin 1 with the Uno disconnected and the drive
powered: it should idle between 3 and 5.5 V (OI-M11).

### 3a. The lab's actual supply: 11.2 V battery, no switch (2026-10-11)

The rig is powered from an **11.2 V battery** (as reported; most likely a 3-cell lithium pack:
12.6 V full, 11.1 V nominal) and there is **no power switch**: the battery is live the
moment its connector is plugged in. Consequences:

- **The battery connector is the emergency stop.** Plug it in **last**, keep it within reach,
  and pull it to stop everything. Nothing else may sit between you and that connector.
- **Fuse is mandatory.** A lithium pack can deliver tens of amps into a short. Put the 5 A
  slow-blow fuse (or an inline blade fuse) in the + lead **at the battery end**.
- **Only the drive takes battery power** (pins 16/17). The Uno stays on USB. Do not connect the
  battery to the Uno's VIN or 5 V.
- **Under-voltage:** the drive needs ≥ 10 V (SRC-002). A 3-cell pack below ~10.5 V (3.5 V/cell)
  is nearly empty: stop and recharge rather than run near the drive's limit. Never store a
  lithium pack discharged.
- **Speed:** at 11.2 V the motor's free-running maximum is ≈ 168 rpm at the output instead of
  180 rpm; keep setpoints ≤ 150 rpm. The model's supply voltage is set to 11.2 V (ASSUMED).
- Power-up order without a switch: wire everything → Uno on USB → firmware connected in MATLAB
  → **plug the battery in last**. Power-down: **unplug the battery first**, then USB.
- **Never leave the battery connected while the Uno has no USB power.** The drive's TXD line
  (5 V idle) then back-powers the Uno through pin D8; the half-powered processor can lock up and
  stay silent after USB returns (observed 2026-10-11 12:13: port open, no `$HELLO`). Recovery:
  battery out → USB out 5 s → USB in → flash/connect → battery in.
- Plugging the battery in can reset the Uno (connector bounce through the shared ground,
  observed twice). Harmless: the firmware boots with the drive stopped; press **Drive check**
  or **Start** and it finds the drive again. A switch or anti-spark connector removes this.

## 4. Drive settings

| Setting | Value | How |
|---|---|---|
| Slave ID | **7 on the lab's drive** (found 2026-10-11); firmware scans 11, 7, 1–6 | as delivered — do not change |
| Lines per rotation (reg 10) | **13** | firmware writes it at boot if different (RAM only, not saved to EEPROM) |
| Mode | digital speed (Mode 1) | firmware |
| UART | 9600 8N1 | fixed |

## 5. Flash and first run (step by step)

**A. Flash (Uno only, drive unpowered)**

1. Plug the Uno into the laptop. Check it appears:
   `scripts/setup/acli board list` → a line with `/dev/ttyACM0 … arduino:avr:uno`.
2. Flash:
   ```bash
   cd ~/Projects/enr312-lab
   scripts/setup/upload motor            # auto-detects the Uno; or: scripts/setup/upload motor /dev/ttyACM0
   ```
   Expect "Sketch uses … bytes" and an avrdude "bytes written / verified" message.
3. Serial Monitor check (optional): Arduino IDE (`~/Applications/arduino-ide_2.3.10_Linux_64bit.AppImage`)
   → Tools → Serial Monitor, **115200 baud, newline**. With no drive powered you should see
   `# no RMCS-2303 answered …` then `$HELLO,1,enr312_motor,<rev>,0*..`. **Close the Serial Monitor
   before connecting MATLAB** (only one program may hold the port).

**B. Wire (everything unpowered)** per section 1 and the circuit diagram. Photograph it.
Motor clamped; output shaft free (a tape flag on it to see rotation).

**C. Power the drive**: switch on the 12 V. The drive's LED should come on; nothing should move.

**D. MATLAB**

1. `MotorControlApp` → **Data source: Hardware** → choose `/dev/ttyACM0` (press Refresh if it
   is missing) → **Connect**. The status line should read
   `Connected: enr312_motor rev …, RMCS-2303 slave id 11`.
   If it says "NO DRIVE answered": check 12 V, D8↔pin 3, D9↔pin 2, GND↔pin 1, then press **Drive check**.
2. **Drive check (read RMCS-2303 registers)**: shows mode, gains, LPR (must read **13**),
   acceleration, speed. Copy the text into the MOTOR-01 record.
3. **Plant = Lab rig**, preset **"Rig - speed - open loop (drive only)"**, set the setpoint
   slider to **20 rpm**, press **Start**. The shaft should turn slowly; the plot shows the
   measured speed over the grey simulation prediction.
4. Press **Stop (hold)**: the motor stops and holds. Start again, press **E-STOP**: the motor
   stops and goes limp. Then test the **D4 button** and the **12 V switch**.
5. Watchdog: during a run, close the MATLAB app window. The motor must stop within ~1 s.
6. Direction: with a positive speed command the measured speed must be positive. If the app shows
   `runaway: wrong way`, red and orange are on the wrong pins (red must be on 11, orange on 10).
7. **Live driving:** Run length **Until Stop (hardware)**, then **Start**, then move the **Setpoint**
   slider: the new rpm (−150 … +150, negative = reverse) goes to the motor immediately.
8. **Hardware experiments** (section in the app): pick one of the 10 (MOTOR-02 … 07), read its
   description, **Run experiment**. Setpoints play automatically; every run is saved to
   `data/raw/dc_motor/` (read-only) with metadata. Any firmware error (runaway, Modbus loss)
   aborts the experiment and shows a red popup. After an E-STOP press **Clear E-STOP**.

Tested end to end on 2026-10-11 against the real firmware code and an emulated drive
(`matlab/tests/e2e/e2e_motor_app_pty.m`, 10/10): connect, Drive check, live setpoint,
E-STOP latch, automatic experiment with raw-data export.

**If something is wrong**

| Symptom | Likely cause |
|---|---|
| upload: "permission denied" on /dev/ttyACM0 | user not in `dialout` (this laptop: it is) — log out/in |
| upload: "programmer is not responding" | Serial Monitor or MATLAB still holding the port; wrong board |
| no `$HELLO` in MATLAB | Serial Monitor open elsewhere; wrong firmware |
| HELLO says slave id 0 | drive unpowered, TX/RX swapped, GND missing |
| `MODBUS_TIMEOUT` flag during a run | loose D8/D9 wire, drive reset by supply dip |
| speed reads ~25× wrong | LPR not 13 (Drive check shows it) |
| motor runs the wrong way | expected sign issue C-M3: note it; swap motor leads only if the course needs a fixed direction |

## 6. Hazards

Geared output ~1.5 N·m at up to 180 rpm: it can trap fingers and fling loose parts. Keep hands
off while enabled. Do not stall the motor for long at full command (3 A continuous heats the
motor). Do not rewire while powered.
