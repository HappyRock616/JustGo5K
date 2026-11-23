#!/usr/bin/env bash
# Build Just Go 5K for one device and load it into the Connect IQ simulator.
# Usage: scripts/sim.sh [device-id]   (default: vivoactive5)
set -e
DEV="${1:-vivoactive5}"
cd "$(dirname "$0")/.."
SDK="$(tr -d '\r\n' < "$APPDATA/Garmin/ConnectIQ/current-sdk.cfg")"
KEY="${CIQ_DEV_KEY:-$HOME/Documents/keys/GarminConnectIQ/garmin-connectiq-developer-key.der}"
mkdir -p bin
"$SDK/bin/monkeyc.bat" -f monkey.jungle -d "$DEV" -o "bin/JustGo5K-$DEV.prg" -y "$KEY" -w
if ! tasklist //FI "IMAGENAME eq simulator.exe" | grep -q simulator.exe; then
  cmd.exe //c start "" "$SDK\\bin\\simulator.exe"
  sleep 8
fi
nohup "$SDK/bin/monkeydo.bat" "bin/JustGo5K-$DEV.prg" "$DEV" >/dev/null 2>&1 &
sleep 6
echo "Loaded on $DEV"
