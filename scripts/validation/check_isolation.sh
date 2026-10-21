#!/usr/bin/env bash
# Check that ENR312 is isolated from other projects on this machine (e.g. the
# odyssix / STM32 pendulum work): no references, no shared toolchain state.
# Exit 1 on any violation.
set -uo pipefail
root="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
cd "$root"
fail=0
say() { printf '%-6s %s\n' "$1" "$2"; }

# 1. No references to other projects in code, firmware, data or results.
#    Allowed: MATLAB_ARCHITECTURE.md (UI style credit),
#    this script, setup comments and machine paths that merely contain the username.
hits="$(grep -rniE 'odyssix_stm32|stm32cube|edukit|steval|bfmc|nucleo|EXP00[1-5]' \
        --include=*.m --include=*.ino --include=*.cpp --include=*.h --include=*.yaml --include=*.json \
        --include=*.csv --include=*.md --include=*.py --include=*.sh . 2>/dev/null \
        | grep -vE '^\./(docs/architecture/MATLAB_ARCHITECTURE\.md|scripts/validation/check_isolation\.sh|matlab/setup_enr312\.m|scripts/setup/arduino-cli\.yaml):')"
if [ -n "$hits" ]; then say FAIL "references to other projects:"; echo "$hits"; fail=1; else say OK "no references to other projects in code/data/docs"; fi

# 2. Arduino toolchain is the isolated one.
cfg="$root/scripts/setup/arduino-cli.yaml"
if grep -q 'arduino-enr312' "$cfg"; then say OK "arduino-cli uses ~/Projects/tools/arduino-enr312 (not ~/.arduino15 or ~/Arduino)"; else say FAIL "arduino-cli config not isolated"; fail=1; fi
for lib in "DHT sensor library" "AltSoftSerial"; do
  [ -d "$HOME/Projects/tools/arduino-enr312/user/libraries/${lib// /_}" ] && say OK "library '$lib' in the isolated sketchbook" || say WARN "library '$lib' not found in the isolated sketchbook"
done

# 3. MATLAB path set-up only adds folders inside this repository.
if grep -E "addpath" matlab/setup_enr312.m | grep -vqE "fullfile\((here|a\.folder|m\.folder)"; then say FAIL "setup_enr312.m adds a path outside the repo"; fail=1; else say OK "setup_enr312.m adds only repository folders"; fi
for f in "$HOME/Documents/MATLAB/startup.m" "$HOME/MATLAB/startup.m"; do
  [ -f "$f" ] && grep -qiE 'odyssix|stm32' "$f" && { say WARN "$f mentions another project: it runs in every MATLAB session"; }
done

# 4. Simulink models and MATLAB packages are namespaced.
ls matlab/models/*/*.slx 2>/dev/null | grep -v '/enr312_' && { say FAIL "Simulink model without enr312_ prefix"; fail=1; } || say OK "Simulink models are enr312_* (no name clash with other projects)"
[ -d matlab/functions/+enr312 ] && say OK "MATLAB code lives in the +enr312 package namespace"

# 5. Git remote (if any) is this project's own.
r="$(git remote -v 2>/dev/null | head -1)"
[ -z "$r" ] && say INFO "no git remote yet" || { echo "$r" | grep -qiE 'odyssix_stm32|bfmc' && { say FAIL "remote points at another project: $r"; fail=1; } || say OK "git remote: $r"; }

exit $fail
