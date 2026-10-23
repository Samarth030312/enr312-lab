# ENR312 MOTOR handout: how this rig answers every task and question

Source: ENR312 *DC Motor Control Experiment (MOTOR)* guidelines, SRC-013 (not redistributed).
Apparatus (unchanged): Arduino Uno + Robokits **RMCS-2303** servo drive + **RMCS-5032** geared
motor, 11.2 V battery. The handout is written for a bare motor on a PWM driver; where it says
"PWM 0–255" our actuator command is the drive's **speed command in output rpm (0–180)**, and the
answers explain the difference instead of hiding it.

Status legend: **DONE-HW** answered from hardware data · **DONE-SIM** answered by simulation/analysis ·
**PENDING-HW** run the named experiment on the rig (`enr312_motor` → its mission → RUN ON RIG), then
`matlab/scripts/motor_session_report.m` for that day.

Generated numbers and figures: [`COURSE_SIM_RESULTS.md`](COURSE_SIM_RESULTS.md) (do not edit; regenerate).
Hardware session records: [`HW-SESSION-20261011-1314_FINDINGS.md`](HW-SESSION-20261011-1314_FINDINGS.md) and
[the 2026-10-23 course session](../../../results/reports/dc_motor/2026-10-23/REPORT.md) (S3-2, 3, 5, 9, 10, 12 on the rig).

## Section 1 — tasks

| Task | Where it is done | Status |
|---|---|---|
| 1. Identify the motor, note its specifications | `docs/knowledge-base/HARDWARE_REFERENCE.md` §1; `enr312.motor.params` | DONE |
| 2. Read the driver sheet, learn to drive the motor | HARDWARE_REFERENCE §2 (modes, registers, scaling); firmware header | DONE |
| 3. Arduino controls 1) position 2) speed | firmware loops **P** (position) and **S/E** (speed); 20 runs on 2026-10-11 | DONE-HW |
| 4. Explore P, I, PI for position and speed | hardware runs MOTOR-03…07 (2026-10-11) + "Course S3-x" experiments (2026-10-23) | DONE-HW |

## Section 2 — questions (reference answers for this rig)

**Q1 How does the geared motor with encoder work?** A permanent-magnet DC motor: armature current
in the magnetic field gives torque T = Kt·i, rotation induces a back-EMF e = Ke·ω, so speed rises until
the back-EMF nearly balances the supply. A 100:1 planetary gearbox trades speed for torque
(18000 rpm → 180 rpm; 0.015 → 1.5 N·m). A 13-pole magnetic (Hall) encoder on the motor shaft gives two
square waves A and B, 90° apart: 13 lines per motor turn, 52 edges, 5200 counts per output turn.

**Q2 How is power provided?** Motor: from the drive's H-bridge outputs (pins 14/15), which take
their energy from the drive supply on pins 16 (+) / 17 (−): 10–30 V DC, here an 11.2 V battery
(a 12 V ≥ 5 A bench supply or adapter is the alternative; always fused). Drive logic: generated on
the drive from the same supply; the drive also powers the encoder (+5 V on pin 9). Arduino: USB 5 V
from the laptop (alternatives: 7–12 V barrel jack/VIN, regulated 5 V pin). Never power the motor
from the Arduino.

**Q3 Motor to driver.** Motor leads → pins 14/15; encoder GND/+5 V/B/A → pins 8/9/10/11. Lab cable
colours: [`DC_MOTOR_WIRING.md`](../../wiring/DC_MOTOR_WIRING.md) §1 (datasheet colours differ on our cable).

**Q4 How is P control employed?** Every Ts the Arduino reads the measurement, computes
e = r − y and sends u = Kp·e to the drive (speed command, limited to ±uMax). Speed P leaves an error
e_ss = r/(1+Kp) (measured 49.5/40.2/33.2 rpm for Kp 0.2/0.5/0.8 at 60 rpm, theory 50/40/33.3).

**Q5 How is I control employed?** u = Ki·Σe·Ts (the error is accumulated every sample, with
clamping anti-windup at ±uMax). It removes steady-state error but responds slowly and, with an
integrating plant (position), oscillates (MOTOR-06).

**Q6 How do you know control is applied?** The measured value follows the setpoint and the
controller output changes in response to the error (live plots, `u` column of every run); applying a
disturbance by hand produces a corrective change of u; P control shows the predicted offset, PI removes it.

**Q7 What is an encoder, how does it work?** A sensor that converts shaft rotation into pulses.
Two channels A/B in quadrature: the order of edges gives the direction, the count gives the angle;
counts per time give speed. ×4 decoding counts every edge of both channels.

**Q8 Arduino to motor and driver.** The Arduino talks only to the drive: D9 → drive RXD (pin 2),
D8 ← drive TXD (pin 3), GND ↔ pin 1, Modbus ASCII at 9600 baud (AltSoftSerial). STOP button D4 → GND.
The encoder goes to the drive, which counts it; the Arduino reads the counts over Modbus.

**Q9 Position control in real life.** Robot joints, CNC axes, 3-D printers, camera gimbals, valve
and antenna positioning, steering actuators.

**Q10 Speed control in real life.** Conveyors, fans and pumps, electric vehicles, spindles,
treadmills, cruise control, tape/web transport.

## Section 3 — additional questions

| Q | Answer source | Status |
|---|---|---|
| S3-1 specs, counts/rev, resolution | COURSE_SIM_RESULTS §S3-1: 5200 counts, 0.0692° | DONE |
| S3-2 speed resolution for 10/50/100 ms; window used; noise vs delay | §S3-2: 1.154 / 0.231 / 0.115 rpm; drive register = one encoder line per ~10 ms (4.62 rpm steps, MEASURED); loop E = counts over Ts | DONE-HW for each feedback separately (register: 0→60 step; encoder: static map, I sweep); the back-to-back pair was stopped by the runaway guard 3 of 3 times, see the 2026-10-23 report, Safety events |
| S3-3 static map, dead zone, saturation | **no dead zone** (2 rpm → 2.04 rpm), slope 0.997 / 0.998 fwd / rev, linear to 150 rpm (2026-10-23); saturation 161–170 rpm at 11.2 V (2026-10-11) | DONE-HW |
| S3-4 K and τ from a step; first-order adequate? | §S3-4: K = 1.02 ± 0.06; τ depends on step size → rate limit 53 rpm/s fits all runs (RMSE ≈ quantisation); 2026-10-23: rise 0.90 s, slope 53.3 rpm/s, K 1.000 (model predicted 0.80 s, 53.4) | DONE-HW |
| S3-5 position P final error, ≥3 Kp | §S3-5: ≤ 0.56° for Kp 0.2/0.3/0.5 (HW); 10° moves: −0.11 / −0.17 / −0.11° for Kp 0.1 / 0.3 / 1.0, Kp 1.0 overshoots 56 % (2026-10-23) | DONE-HW |
| S3-6 loop time with micros() | firmware measures it; DRIVE CHECK prints mean/max: **74.4–74.6 ms per 100 ms sample, max 74.7 ms, 0 overruns** (2026-10-23, `results/evidence/logs/hw_check_20261023-1*.log`); the Modbus budget estimate was 69 ms | DONE-HW |
| S3-7 Simulink model with K, τ, limits, dead zone, quantisation vs measured P/I/PI | `matlab/models/dc_motor/enr312_motor_identified.slx`; §S3-7 table and figure (14 hardware runs predicted) | DONE |
| S3-8 +50 % inertia | §S3-8: rig unchanged (drive has 22× torque margin at its ramp); bare-motor model slows and overshoots more | DONE-SIM |
| S3-9 I-only characteristic equation, damping vs Ki | §S3-9 derivation, ζ table; rig overshoot 0 / 2.7 / 1.6 / 58.7 % for Ki 0.5 / 1 / 2 / 4 against 0.9 / 10 / 24 / 38 % from the delay-free formula; the identified model predicts the rig (2026-10-23) | DONE-HW |
| S3-10 PI design ζ = 0.7, predicted vs measured | Kp 1.0, Ki 2.9; theory 4.6 %, model 25.8 %, **rig 29.0 %**, then a **±6.7 rpm limit cycle** the model also shows: the design ignored the 70 ms latency (2026-10-23) | DONE-HW |
| S3-11 why P stops short; backlash hunting | §S3-11: e = d/Kp with a dead zone; hunting needs a load-side sensor | DONE-SIM (rig evidence in S3-5) |
| S3-12 integral windup, where, code fix | rig with the firmware's clamping: back within 5 % of 30 rpm **0.5 s** after the drop (model 0.5 s); model with a plain integrator: not back within 6 s; code in `pidStep` (firmware and `pidStep.m`) | DONE-HW |

## Running everything

1. Simulation and analysis (no hardware): `matlab -batch "cd matlab/scripts; motor_course_questions"`.
2. Hardware: `enr312_start` → plug in the Uno (the app offers to flash and connect) → battery on →
   **DRIVE CHECK** (LPR must read 13) → pick the mission (M1–M9) and a preset, or "▶▶ all runs" →
   **RUN ON RIG**. Each run is saved to `data/raw/dc_motor/` automatically and appears under RUNS.
   If the firmware stops the motor, the app says why; press **CLEAR FAULT** before the next run.
3. Analyse: `matlab -batch "cd matlab; run('setup_enr312.m'); motor_session_report('YYYY-MM-DD')"`.
