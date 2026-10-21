# Pneumatic control — edge-folding device (Festo FluidSIM)

Course: SRC-001 pp.27–29 (Assignment 4, Pneumatic guideline, lab report p.41).
**Simulation tool: Festo FluidSIM only** (the Festo product the lab uses). There is no MATLAB
pneumatic model in this repository, by decision of the project owner (2026-10-09).

## Status (2026-10-09)

| Item | Status |
|---|---|
| Circuit read from the course diagram, components identified | DONE — below |
| FluidSIM account / licence (student's university account) | **NOT DONE — needs the student** (sign-up needs your password and email verification) |
| Circuit 01 (course circuit) built in FluidSIM | NOT STARTED — step-by-step in `fluidsim/circuit_01_edge_folding/BUILD.md` |
| Circuit 02 (variant without quick-exhaust, for question 21) | NOT STARTED — `fluidsim/circuit_02_without_quick_exhaust/BUILD.md` |
| Screen-recording workflow | READY — `scripts/recording/record_screen.sh` |

## 1. Getting FluidSIM (student action)

1. Open <https://www.festo.com/us/en/e/technical-education/digital-learning/virtual-simulation-and-modeling/fluidsim-id_1663056>
   (FluidSIM product page) and choose the **FluidSIM Pneumatics** trial / education licence.
2. Create or sign in to a **Festo account with your university email** (Festo LX:
   <https://lx.festo.com/>). Verify the email from your university inbox.
3. Ask the lab instructor whether Ahmedabad University has a FluidSIM campus licence you should
   use instead of the trial — the course says "we are using the Festo version", so a lab licence
   may already exist.
4. Start FluidSIM: the browser version at <https://fluidsim.festo.com/> works on Ubuntu. The
   desktop FluidSIM is Windows-only; do not install cracked copies or rely on Wine.
5. Record in `docs/knowledge-base/SOFTWARE_TOOLCHAIN.md`: product, version, licence type,
   expiry date.

## 2. The circuit (from the course diagram, p.28)

| Tag | Component (diagram symbol) | Role |
|---|---|---|
| 1A | Double-acting cylinder | Folding tool |
| 1S1, 1S2 | 3/2-way push-button valve, normally closed, spring return | The two hands |
| 1V1 | **Two-pressure valve (AND)** | Passes a signal only while both 1S1 and 1S2 are pressed |
| 1V2 | **5/2-way valve, pneumatically piloted, spring return** | Main valve: piloted → extend; released → retract |
| 1V3 | **One-way flow control valve** (throttle + check) on the cap side | Free flow in → fast extend; throttled exhaust → **slow return** |
| 1V4 | **Quick-exhaust valve** on the rod side | Dumps rod-side air during extension → **fast extend** |
| 1Z1, 1Z2 | Pressure gauges, cap side and rod side | Tasks 7 and 13 |
| 0Z | Compressed-air supply + service unit (filter, regulator) | Not drawn; required (question 18) |

Displacement-step diagram: 1A extends (step 1→2) and returns (2→3=1).

**Conflict C-P1:** the guideline text lists "1V1, 1V2, 1V3, 1V4 – directional, shuttle, flow
control, check" and question 11 calls 1V2 a shuttle valve. The diagram shows 1V1 as a
two-pressure (AND) valve, 1V2 as a 5/2 directional valve and 1V4 as a quick-exhaust valve.
**Build from the diagram**, and say so in the report: a shuttle (OR) valve in place of 1V1 would
let either single button fire the press, defeating the two-hand safety function.

## 3. Experiments in FluidSIM

| ID | Course task | What to do and record |
|---|---|---|
| PNEU-01 | 3, 7, 10 | Press 1S1 + 1S2 together: full stroke. Read 1Z1/1Z2 at end of extension and retraction. |
| PNEU-02 | 9 | Press only 1S1, then only 1S2: no motion. Explain via 1V1 (AND). |
| PNEU-03 | 3, 5 | Release one button mid-stroke: 1A returns slowly. |
| PNEU-04 | 4, 8, 23 | 1V3 at 100 / 50 / 25 / 10 % opening: retraction time vs restriction (table + plot). |
| PNEU-05 | 6, 21 | Circuit 02 (1V4 replaced by a plain line): compare extension time. |

For each run: save the native circuit file in the circuit folder, record the screen
(`scripts/recording/record_screen.sh pneumatic PNEU-01-FS-001`), export the FluidSIM
displacement/pressure diagrams as images, and note times in the circuit folder's `RESULTS.md`.

## 4. Real kit safety (hands-on session)

Supply ≤ 6 bar through the service unit. Push tubes fully home and tug-test them. Depressurise
before changing tubing. Keep hands out of the cylinder's path: that is the whole point of the
two-hand control. Eye protection when air lines are being connected.
