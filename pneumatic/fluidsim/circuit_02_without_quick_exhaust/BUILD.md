# Circuit 02 — edge-folding device without the quick-exhaust valve — FluidSIM build steps

Purpose: course question 21 / task 6 — what 1V4 does. Same as circuit 01 with **1V4 removed and
1V2 port 2 piped straight to the cylinder rod side**. During extension the rod-side air must now
leave through 1V2's exhaust, so extension is slower.

1. Open circuit 01, **Save As** `circuit_02_without_quick_exhaust` in this folder.
2. Delete 1V4; connect 1V2 port 2 directly to the rod-side port (keep gauge 1Z2 on that line).
3. Keep 1V3 at the opening used in circuit 01 (30 %).
4. Run PNEU-05-FS-001: hold both buttons, release. Record with
   `scripts/recording/record_screen.sh pneumatic PNEU-05-FS-001`.
5. In `RESULTS.md`, compare extension time and the 1Z2 pressure trace with circuit 01.
