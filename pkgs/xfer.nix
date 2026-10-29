# `xfer`: file transfer between the Mac mini and the ThinkPad. One script (xfer.sh); each host
# builds it with the other machine's ssh name as `peer` (XFER_PEER overrides it, for testing).
{ writeShellApplication, rsync, openssh, peer }:

writeShellApplication {
  name = "xfer";
  runtimeInputs = [ rsync openssh ];
  text = ''
    export XFER_PEER="''${XFER_PEER:-${peer}}"
  '' + builtins.readFile ./xfer.sh;
}
