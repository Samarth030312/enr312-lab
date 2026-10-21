#!/usr/bin/env bash
# Record the screen (or one window region) to an MP4 for evidence, e.g. a FluidSIM run.
#   scripts/recording/record_screen.sh <subsystem> <run_id> [seconds]
#   -> results/evidence/screen_recordings/<subsystem>/<run_id>/screen.mp4  (+ README.md)
# Stop early with Ctrl+C (the file is finalised). Uses ffmpeg x11grab on $DISPLAY (X11).
# To capture only a window: set REGION="WxH+X+Y" (find it with: xwininfo, click the window).
set -euo pipefail
root="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
sub="${1:?subsystem (e.g. pneumatic)}"; run="${2:?run id (e.g. PNEU-01-FS-001)}"; secs="${3:-120}"
out="$root/results/evidence/screen_recordings/$sub/$run"
[ -e "$out/screen.mp4" ] && { echo "refusing to overwrite $out/screen.mp4 (run IDs are never reused)"; exit 1; }
mkdir -p "$out"
REGION="${REGION:-}"
if [ -z "$REGION" ]; then size="$(xdpyinfo | awk '/dimensions/{print $2}')"; off="0,0"
else size="${REGION%%+*}"; off="${REGION#*+}"; off="${off/+/,}"; fi
echo "Recording $DISPLAY $size at +$off for up to $secs s -> $out/screen.mp4  (Ctrl+C to stop)"
ffmpeg -loglevel error -y -f x11grab -framerate 15 -video_size "$size" -i "$DISPLAY+$off" -t "$secs" \
       -c:v libx264 -preset veryfast -pix_fmt yuv420p "$out/screen.mp4" || true
dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out/screen.mp4" 2>/dev/null || echo 0)"
cat > "$out/README.md" <<MD
# $run

- Subsystem: $sub
- Recorded: $(date -Iseconds) on $(hostname), display $DISPLAY, region ${REGION:-full screen}
- File: screen.mp4 ($dur s, ffmpeg x11grab, 15 fps)
- What is shown: (fill in: software + version, circuit file, operator actions)
- Data class: SIMULATION (screen recording of the simulation software)
MD
echo "Saved $out/screen.mp4 ($dur s)"
