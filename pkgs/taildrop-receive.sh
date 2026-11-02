# taildrop-receive: pulls files sent with Taildrop (e.g. from the iPhone's share sheet) out of tailscaled's
# inbox into ~/Transfer, then shows the same notification as a file from the mini. Runs as a user service;
# needs the user to be tailscale's operator (services.tailscale.extraSetFlags).
dir=$HOME/Transfer
mkdir -p "$dir"
marker=$(mktemp)
trap 'rm -f "$marker"' EXIT
while true; do
  touch "$marker"
  # Blocks until something arrives; on error (tailscaled down) exit and let systemd restart us
  tailscale file get --wait --conflict=rename "$dir"
  # Taildrop doesn't keep mtimes, so whatever is newer than the marker is what just landed
  mapfile -t new < <(find "$dir" -maxdepth 1 -type f -newer "$marker" -printf '%f\n')
  if [ ${#new[@]} -gt 0 ]; then
    XFER_FROM="From Taildrop" xfer-notify "$dir" "${new[@]}"
  fi
done
