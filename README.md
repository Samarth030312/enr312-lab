# ENR312 Control Engineering Lab

Temperature control, DC-motor control and pneumatic simulation for ENR312 (Ahmedabad
University, Monsoon 2025-26), with MATLAB/Simulink simulation, MATLAB live interfaces and
reproducible evidence. The pendulum experiment lives in a separate repository.

Start with `docs/knowledge-base/INDEX.md`.

| Subsystem | Status | Start here |
|---|---|---|
| DC motor | Simulation, Simulink model, app and evidence done; firmware and hardware not started | `dc_motor/README.md` |
| Temperature | Not started | `temperature/` |
| Pneumatic | Not started | `pneumatic/` |

```bash
matlab -r "run('matlab/setup_enr312.m'); MotorControlApp"
matlab -batch "cd matlab/tests; results = runtests; assertSuccess(results)"
```

Requirements: MATLAB R2026a; Simulink for the Simulink model and its cross-check test;
ffmpeg for MP4 recordings. Details: `docs/knowledge-base/SOFTWARE_TOOLCHAIN.md`.
