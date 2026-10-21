# Circuit 01 — edge-folding device (course circuit) — FluidSIM build steps

Source: SRC-001 p.28 diagram. Save the result here as `circuit_01_edge_folding.<FluidSIM extension>`.
Component names follow FluidSIM's Pneumatics library; exact menu names can differ by version.

## Place

1. **Compressed air supply** (Supply elements) at the bottom; add a **service unit** /
   pressure regulator set to **6 bar**.
2. **1S1** and **1S2**: *3/n way valve* → configure as **3/2-way, normally closed**,
   actuation **pushbutton**, return **spring**. Place side by side.
3. **1V1**: *Two-pressure valve* (AND). Inputs from 1S1 port 2 and 1S2 port 2.
4. **1V2**: *5/n way valve* → **5/2-way**, actuation **pneumatic (pilot)** on the left,
   **spring** return on the right. Pilot port 14 ← 1V1 output.
5. **1V3**: *One-way flow control valve*. Between 1V2 port **4** and the cylinder **cap-side**
   port, oriented so the **check opens towards the cylinder** (free flow in, throttled flow out).
   Set opening to **30 %** to start.
6. **1V4**: *Quick exhaust valve*. Between 1V2 port **2** and the cylinder **rod-side** port.
7. **1A**: *Double-acting cylinder*. Set stroke **100 mm**, piston **20 mm**, rod **8 mm** if the
   dialog allows (otherwise keep defaults and record them).
8. **1Z1** and **1Z2**: *Pressure gauge* on the cap-side and rod-side lines (between 1V3/1V4 and 1A).
9. Connect supply to 1S1 port 1, 1S2 port 1 and 1V2 port 1. Exhausts 3 / 5 to atmosphere.
10. Label each component with its tag (1A, 1S1, ...). Add a **displacement-step diagram** for 1A
    and **pressure–time** plots for 1Z1 and 1Z2 (State diagram / Diagram tools).

## Check before simulating

- At rest (no button pressed) the cylinder must be **retracted** and 1Z2 at supply pressure.
- Pressing only one button changes nothing at 1V2.

## Runs to record

| Run ID | Action | Expected |
|---|---|---|
| PNEU-01-FS-001 | Hold 1S1 + 1S2 (use the lock / Ctrl-click to hold both) | fast extension, then hold |
| PNEU-01-FS-001 (cont.) | Release both | **slow** retraction (1V3 throttled) |
| PNEU-02-FS-001 | 1S1 only, then 1S2 only | no motion |
| PNEU-03-FS-001 | Both, release one mid-stroke | immediate slow return |
| PNEU-04-FS-00{1..4} | 1V3 at 100, 50, 25, 10 % | retraction time grows as the throttle closes |

Record each with `scripts/recording/record_screen.sh pneumatic <run id>` and write the measured
extension/retraction times and gauge readings in `RESULTS.md` next to this file.
