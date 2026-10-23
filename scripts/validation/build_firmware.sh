#!/usr/bin/env bash
# Compile every ENR312 sketch (all variants), then run the host-side firmware tests.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
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
"$root/scripts/validation/host_tests.sh"
