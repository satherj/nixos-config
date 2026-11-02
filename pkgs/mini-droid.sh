# `mini-droid`: watch and click the mini's Android emulator from this ThinkPad.
# Opens an ssh tunnel to the mini's adb server (5037) and scrcpy's video port (27183), runs scrcpy through it, and
# closes the tunnel when scrcpy exits. Start the emulator on the mini first (`ssh mini`, then
# `apps/android/scripts/droid up`). A local adb server would hold 5037, so it is stopped first.
adb kill-server 2>/dev/null || true

ssh -CN -o ExitOnForwardFailure=yes -L5037:localhost:5037 -L27183:localhost:27183 mini &
tunnel=$!
trap 'kill "$tunnel" 2>/dev/null || true' EXIT

# wait for the tunnel to listen (up to 15 s)
for _ in $(seq 1 30); do
  if ! kill -0 "$tunnel" 2>/dev/null; then
    echo "mini-droid: the ssh tunnel to the mini failed (is Tailscale up?)" >&2
    exit 1
  fi
  if (exec 3<>/dev/tcp/127.0.0.1/5037) 2>/dev/null; then break; fi
  sleep 0.5
done

if ! ADB_SERVER_SOCKET=tcp:localhost:5037 adb devices | grep -q 'emulator-.*device$'; then
  echo "mini-droid: no emulator on the mini; run apps/android/scripts/droid up there first" >&2
  exit 1
fi

ADB_SERVER_SOCKET=tcp:localhost:5037 scrcpy --force-adb-forward "$@"
