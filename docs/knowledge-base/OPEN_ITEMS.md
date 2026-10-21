# Open Items and Conflicts

An item closes only with evidence (a measurement, an inspection photo, or a document
quote). Record how it was closed.

## Conflicts between sources (DC motor)

| ID | Conflict | Effect | Resolution path | Status |
|---|---|---|---|---|
| C-M1 | Course (SRC-001 week 5) lists a generic DC motor, 6/9 V battery, diode and MOSFET. The lab hardware is an RMCS-2303 servo drive + RMCS-5032 12 V motor. | Firmware and control architecture differ from the course text. | Follow the actual hardware; reproduce the course's generic set-up in simulation ("Bare DC motor" plant). ED-M1. | DECIDED (pending approval) |
| C-M2 | RMCS-5032 title "200RPM" vs table "180RPM". | Max output speed. | Table value 180 is consistent with 18000/100. Confirm in MOTOR-02. | OPEN |
| C-M3 | Encoder A/B colours: drive manual p.5 (generic motor) red=ENC_B; RMCS-5032 sheet red=EncA. | Wiring per the drive manual crossed A/B: runaway on 2026-10-11 (incident report). | **Resolved: follow the RMCS-5032 sheet — red→pin 11, orange→pin 10.** Confirm on the rig after re-wiring. | RESOLVED (doc); re-wire + confirm PENDING |
| C-M4 | Drive pin 11 labelled "Hall V" (p.4) vs "Hall U" (p.5); p.5 tables placed side by side look like a pin mapping but are not. | Wiring error risk. | Wire by function and board silkscreen; photograph. | OPEN |
| C-M5 | Motor max current 7.5 A vs drive 3 A peak. | Stall torque 60 kgf·cm is not reachable; max ≈ 17 kgf·cm (ESTIMATED). | Note in report; model current limit. | NOTED |
| C-M6 | Drive accepts 10–30 V; motor is 12 V. | Over-speed if a 24 V supply is used and a high speed is commanded. | Use 12 V or clamp commanded base speed ≤ 18000 rpm. | OPEN (OI-M1) |
| C-M7 | Robokits product page names the drive "…10 A"; the manual says phase current 0.5–3 A peak. | Unknown true current limit. | Fuse the supply at 5 A regardless; measure supply current under load in MOTOR-02. | OPEN |

## Unresolved facts (DC motor)

| ID | Fact needed | Why it matters | How to resolve | Status |
|---|---|---|---|---|
| OI-M1 | Lab power-supply voltage and current rating | C-M6; safety | Reported 2026-10-11: 11.2 V battery, no switch. Still to read: chemistry, capacity, max discharge (label) | PARTLY RESOLVED |
| OI-M2 | Drive slave ID on the actual unit | Every Modbus frame | **Slave id 7** found by the firmware's scan (session log hw_session_20261011-120813.log). Jumper state still to photograph | **CLOSED 2026-10-11** |
| OI-M3 | UART framing | Communication | Vendor library RMCS2303drive v1.0 (SRC-012): 9600 baud, SoftwareSerial (8N1 only) | **CLOSED 2026-10-09** |
| OI-M4 | Register addressing on the wire | Every Modbus frame | Vendor library: documented numbers go on the wire as-is (2, 14, 24); FC 06 write / FC 03 read; LRC = two's complement; **position feedback = 2 registers from 20, low word first** (manual says 20/22) | **CLOSED 2026-10-09** |
| OI-M5 | Units of the acceleration register (12) | Speed ramp model | Step test in MOTOR-02 | **RESOLVED 2026-10-21**: register 5000 → fitted ramp 53.4 output rpm/s (= 5340 base rpm/s) on 4 open-loop runs: units are base rpm per second (COURSE_SIM_RESULTS S3-4) |
| OI-M6 | Signedness of speed feedback (register 24) | Reverse speed reading | Run reverse in MOTOR-02 | OPEN |
| OI-M7 | Whether PPG / PIG / VFFG act in speed mode | ED-M1 option A | Vary gains in Mode 1 on hardware | OPEN |
| OI-M8 | Real Modbus cycle time on the Uno | Outer-loop Ts (ED-M1) | Timestamp a loop of reads in MOTOR-02 | OPEN |
| OI-M9 | R, K_t, J, b of the base motor | All simulation results | MOTOR-02 identification (multimeter for R; speed step for τ) | OPEN — currently ESTIMATED |
| OI-M10 | Current LPR setting stored in the drive's EEPROM | rpm scaling ×25.7 if wrong | READ_PARAMETER at start of MOTOR-01 | OPEN |
| OI-M11 | Drive UART logic level vs Uno 5 V | Possible damage to drive RX | Measure TXD idle voltage; vendor confirms direct Uno wiring (p.29) | OPEN |

## Environment

| ID | Item | Status |
|---|---|---|
| OI-E1 | Simulink and Control System Toolbox are licensed (`license('test')` = 1) but were **not installed** on 2026-10-09. Installation via `mpm` started that day — see SOFTWARE_TOOLCHAIN.md. | IN PROGRESS |
| OI-E2 | Arduino CLI / IDE | CLOSED 2026-10-09: CLI 1.5.1 (isolated) + IDE 2.3.10 |
| OI-E3 | OBS not installed; ffmpeg 6.x present | OPEN |
| OI-E4 | Course PDFs and manuals are copyrighted ("may not be reproduced"); kept locally, git-ignored | DECIDED |

## Temperature / pneumatic

Sensor: DHT11 (owner, 2026-10-21). Not started: SSR datasheet (zero-cross?), bulb rating, LCD model (parallel or I2C), FluidSIM licence.
