# ENR312 Engineering Knowledge Base

## Purpose

This directory contains the engineering knowledge required to understand,
implement, simulate, test, and reproduce the ENR312 experiments.

## Authority order

1. Course requirements and experiment guidelines.
2. Manufacturer documentation for the actual hardware.
3. Verified measurements from the physical apparatus.
4. Official software and library documentation.
5. Academic control-system references.
6. Explicitly labelled engineering estimates and assumptions.

Never present an estimate as a measured value.

## Required reading order

1. `../requirements/COURSE_REQUIREMENTS.md`
2. `HARDWARE_REFERENCE.md`
3. `ENGINEERING_DECISIONS.md`
4. `OPEN_ITEMS.md`
5. `CONTROL_THEORY.md`
6. `SOFTWARE_TOOLCHAIN.md`
7. `SIMULATION_POLICY.md`
8. `../architecture/SYSTEM_OVERVIEW.md`
9. `../architecture/SERIAL_PROTOCOL.md`
10. `SOURCE_REGISTER.csv`

## Evidence rules

- Record the software version used for every simulation.
- Record initial conditions, parameters, sample times, and controller gains.
- Preserve raw experimental data.
- Label synthetic data as synthetic.
- Never substitute simulated results for physical measurements.
- Preserve screenshots, recordings, and generated figures for reproducibility.
- Record limitations and failed tests, not just successful runs.

## Knowledge status

Every important technical claim must be classified as one of:

| Status | Meaning |
|---|---|
| VERIFIED_FROM_MANUAL | Stated in a registered source; page cited |
| MEASURED | Measured on this lab's apparatus; run ID cited |
| TESTED | Behaviour confirmed by a run or automated test; ID cited |
| ESTIMATED | Derived or typical value; derivation stated |
| ASSUMED | Taken as true without evidence, for a stated reason |
| UNVERIFIED | Unknown; tracked in `OPEN_ITEMS.md` |

## Scope

The project covers temperature control, DC-motor control, pneumatic simulation,
MATLAB visualisation, data acquisition, and experiment reporting.
The pendulum experiment is handled in a separate repository.
