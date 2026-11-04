#!/bin/bash
# Boots the named simulator and waits until it's ready. Usage: ci-boot-simulator.sh "iPhone 17" 27.0
set -euo pipefail
device="$1"
runtime="iOS-${2//./-}"
udid="$(xcrun simctl list devices available -j | DEVICE="$device" RUNTIME="$runtime" python3 -c '
import json, os, sys
devices = json.load(sys.stdin)["devices"]
print(next(d["udid"] for key, group in devices.items() if key.endswith(os.environ["RUNTIME"])
           for d in group if d["name"] == os.environ["DEVICE"]))
')"
echo "Booting $device ($runtime): $udid"
xcrun simctl bootstatus "$udid" -b
