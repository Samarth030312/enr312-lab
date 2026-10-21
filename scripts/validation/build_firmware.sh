#!/usr/bin/env bash
# Compile every ENR312 sketch (all variants) and run the host-side firmware tests.
set -euo pipefail
root="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
acli="$root/scripts/setup/acli"
build() { echo "== $1 $2"; "$acli" compile --fqbn arduino:avr:uno --build-property "compiler.cpp.extra_flags=$2" "$root/$1" | tail -2; }
build dc_motor/firmware/motor_controller ""
build temperature/firmware/temperature_controller ""
build temperature/firmware/temperature_controller "-DLCD_I2C"
build temperature/firmware/temperature_controller "-DDHT_KIND=DHT22"
build temperature/examples/lcd_hello_alignment ""
build temperature/examples/lcd_hello_alignment "-DLCD_I2C"
build water_level/firmware/level_controller ""
build water_level/firmware/level_controller "-DRELAY_ACTIVE_LOW=0"
# host test: run-length moving average == ring buffer (extracts the code from the sketch)
tmp="$(mktemp -d)"
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
# keep a copy for the MATLAB end-to-end test (matlab/tests/e2e/e2e_motor_app_pty.m):
#   matlab -batch "run('matlab/setup_enr312.m'); addpath('matlab/tests/e2e'); e2e_motor_app_pty('$root/dc_motor/tests/fwsim')"
cp "$tmp/fwtest" "$root/dc_motor/tests/fwsim"
rm -rf "$tmp"
