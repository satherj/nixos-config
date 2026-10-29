---
name: xfer
description: Move files between the Mac mini and the ThinkPad over Tailscale. Use when the user wants a screenshot, file or text sent to their laptop (or fetched from the other machine), or anything that used to go through Proton Drive.
---

# xfer: files between the mini and the ThinkPad

Two machines, both on the tailnet: the Mac mini (`mini`, user `mac-mini`, the dev server) and the ThinkPad
(`nixos`, user `jonathans`, where the founder usually is). Run `hostname` to see which one you are on. `xfer`
copies to or from the other one; it never deletes and never overwrites (an existing name gets ` (2)`).
Proton Drive is no longer the way to move files between these two.

```
xfer send <file|dir>... [--to <dir>]         # push to the other machine, default folder ~/Transfer
xfer get <remote path>... [--to <dir>]       # pull from the other machine, default local folder ~/Transfer
xfer get --latest <remote dir> [--to <dir>]  # the newest file in that folder
xfer ls [<remote dir>]                       # list a remote folder, newest first
```

- `--to` names the folder on the receiving machine; it is created if missing.
- Quote a remote `~` (`'~/Pictures/Screenshots'`) so your shell doesn't expand it to your own home.
- Names with spaces work as they are.
- `xfer` prints the absolute path of every file as it now sits on the receiving machine. **Tell the founder that
  path** after a send. Sending from the mini also pops a notification on the ThinkPad.

## Where things are

- ThinkPad screenshots: `~/Pictures/Screenshots/` (`Screenshot from <date time>.png`). From the mini, the
  newest is `xfer get --latest '~/Pictures/Screenshots'`.
- Mini build evidence and `scripts/shot` output: `~/work/fondaro/plans/<id>/shots/`. To show the founder one:
  `xfer send ~/work/fondaro/plans/<id>/shots/<name>.png`.

## Errors

A non-zero exit with rsync's or ssh's message means nothing was copied for that file. If ssh can't reach the
other machine, check `tailscale status`; the laptop may be asleep or off the tailnet.
