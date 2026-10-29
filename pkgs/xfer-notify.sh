# xfer-notify <dest dir> <name>...: the ThinkPad's desktop notification for a file the mini just sent.
# Runs from an ssh session, which has no session bus, so point at the user's.
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
dir=$1
shift
if [ $# -eq 1 ]; then
  what=$1
else
  what="$# files"
fi
notify-send -i document-send "From the mini" "$what → $dir"
