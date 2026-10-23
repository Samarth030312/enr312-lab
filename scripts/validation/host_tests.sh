#!/usr/bin/env bash
# Host-side firmware tests (g++ only, no Arduino toolchain): the real sketches run on the PC
# against emulated hardware. Writes the transcripts that the MATLAB tests use as fixtures.
#   scripts/validation/host_tests.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
# host test: run-length moving average == ring buffer (extracts the code from the sketch)
python3 - "$root/temperature/firmware/temperature_controller/temperature_controller.ino" "$tmp/ma_extracted.inc" <<'PY'
import sys
s = open(sys.argv[1]).read()
i = s.index('struct Run {'); j = s.index('\n}\n', s.index('static void maPush')) + 3
open(sys.argv[2], 'w').write(s[i:j])
PY
g++ -std=c++17 -O1 -I"$tmp" -o "$tmp/tma" "$root/temperature/tests/test_moving_average.cpp" && "$tmp/tma"
# host test: the real temperature firmware against an emulated bulb + DHT11 (every mode + safety);
# transcript -> fixture for matlab/tests/test_temperature_transcript.m
g++ -std=c++17 -O1 -w -include algorithm -I"$root/temperature/tests/host_stubs" -o "$tmp/ttest" "$root/temperature/tests/firmware_host_test.cpp"
"$tmp/ttest" "$root/temperature/tests/fixtures/temperature_transcript.txt"
# host test: the real water-level firmware against an emulated tank, pump and HC-SR04 (control + guards)
g++ -std=c++17 -O1 -w -include algorithm -I"$root/water_level/tests/host_stubs" -o "$tmp/ltest" "$root/water_level/tests/firmware_host_test.cpp"
"$tmp/ltest" "$root/water_level/tests/fixtures/level_transcript.txt"
# host test: the real motor firmware against an emulated RMCS-2303; its transcript is
# the fixture for matlab/tests/test_firmware_transcript.m
g++ -std=c++17 -O1 -w -include algorithm -I"$root/dc_motor/tests/host_stubs" -o "$tmp/fwtest" "$root/dc_motor/tests/firmware_host_test.cpp"
"$tmp/fwtest" "$root/dc_motor/tests/fixtures/firmware_transcript.txt"
# keep a copy for the MATLAB end-to-end test (matlab/tests/e2e/e2e_motor_mission_control.m):
#   matlab -batch "cd matlab; run('setup_enr312.m'); addpath('tests/e2e'); e2e_motor_mission_control('../dc_motor/tests/fwsim')"
cp "$tmp/fwtest" "$root/dc_motor/tests/fwsim"
rm -rf "$tmp"
# real-time emulators for the MATLAB end-to-end tests of enr312_temp and enr312_water (--pty mode)
g++ -std=c++17 -O1 -w -include algorithm -I"$root/temperature/tests/host_stubs" -o "$root/temperature/tests/tempsim" "$root/temperature/tests/firmware_host_test.cpp"
g++ -std=c++17 -O1 -w -include algorithm -I"$root/water_level/tests/host_stubs" -o "$root/water_level/tests/levelsim" "$root/water_level/tests/firmware_host_test.cpp"
