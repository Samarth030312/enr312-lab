# Sourced by the scripts in scripts/setup and scripts/validation (bash, Linux and macOS).
# Same folders as enr312.tools.paths in MATLAB; ENR312_TOOLS overrides the default.
#   ENR312_ROOT   repository root
#   ENR312_CLI    arduino-cli executable of this project
# and exports the ARDUINO_DIRECTORIES_* variables, so arduino-cli and the Arduino IDE
# use this project's own cores and libraries (the global ~/.arduino15 is never touched).
ENR312_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -z "${ENR312_TOOLS:-}" ]; then
  case "$(uname -s)" in
    Darwin) ENR312_TOOLS="$HOME/Library/Application Support/enr312" ;;
    *) if [ -d "$HOME/Projects/tools/arduino-enr312" ]; then ENR312_TOOLS="$HOME/Projects/tools"
       else ENR312_TOOLS="$HOME/.local/share/enr312"; fi ;;
  esac
fi
ENR312_CLI="$ENR312_TOOLS/arduino-cli/arduino-cli"
export ARDUINO_DIRECTORIES_DATA="$ENR312_TOOLS/arduino-enr312/data"
export ARDUINO_DIRECTORIES_DOWNLOADS="$ENR312_TOOLS/arduino-enr312/downloads"
export ARDUINO_DIRECTORIES_USER="$ENR312_TOOLS/arduino-enr312/user"
export ARDUINO_UPDATER_ENABLE_NOTIFICATION=false
