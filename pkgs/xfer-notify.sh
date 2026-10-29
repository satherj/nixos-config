# xfer-notify <dest dir> <name>...: the ThinkPad's desktop notification for a file the mini just sent.
# Clicking it shows the file in Nautilus (the folder, for several files).
# Runs from an ssh session, which has no session bus, so point at the user's.
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
dir=$1
shift
# The mini passes the folder as typed: `~/Transfer`, or relative to the home
# shellcheck disable=SC2088 # matching a literal ~, not expanding one
case "$dir" in
  "~") dir=$HOME ;;
  "~/"*) dir=$HOME/${dir#"~/"} ;;
  /*) ;;
  *) dir=$HOME/$dir ;;
esac
if [ $# -eq 1 ]; then
  what=$1
  method=ShowItems
  target=$dir/$1
else
  what="$# files"
  method=ShowFolders
  target=$dir
fi
# FileManager1 takes URIs: percent-encoded (quotes too, so it's safe inside the GVariant string), slashes kept
uri=$(jq -rn --arg p "$target" '"file://" + ($p | @uri | gsub("%2F"; "/"))')

# notify-send waits for the click while it has an action, so wait in the background and let the mini's ssh
# return now. An hour is long enough to still be useful; after that the click does nothing.
(
  clicked=$(timeout 1h notify-send -i document-send -A default="Show in Files" "From the mini" "$what → ${dir/#"$HOME"/\~}" || true)
  if [ "$clicked" = default ]; then
    gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 \
      --method "org.freedesktop.FileManager1.$method" "['$uri']" ""
  fi
) </dev/null >/dev/null 2>&1 &
