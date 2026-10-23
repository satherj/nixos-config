# Desktop design principles

Why the Quickshell desktop in [`quickshell/`](../quickshell) looks and moves the way it does.
Read this before reworking the shell, so new parts keep the same direction. The rules come from
Emil Kowalski's animation skills and Apple's interface guidelines
([emilkowalski/skills](https://github.com/emilkowalski/skills): `improve-animations`,
`review-animations`, `apple-design`), applied to a keyboard-heavy Linux desktop.

The one-line version: **a calm, fast desktop where motion explains things and never makes you wait.**

## 1. Motion

### Should it animate at all?

How often a thing happens decides whether it moves.

| How often | Rule | Here |
| --- | --- | --- |
| Many times an hour, from the keyboard | **No animation, ever** | Launcher (Super+Space), clipboard and keybind modes, wallpaper picker, panels opened by a keybind or closed with Esc |
| Tens of times a day, by pointer | Barely-there feedback | Hover colours, press scale, bar tooltips |
| Occasionally | Standard motion | Panels opened by click, toasts, OSD, polkit dialog, toggles |
| Rarely | Allowed a little delight | Theme switch colour morph, power-button fuse, calendar paging |

Keyboard-triggered UI is the important exception: Raycast and Spotlight have no open/close
animation, because something you summon hundreds of times a day must appear the instant you ask.
`UiState.toggle/close(..., keyboard = true)` sets `UiState.instant`, and `PanelCard` skips its
animation then. The same panel opened with a click still animates.

### Timing and easing

Everything uses the tokens in [`Theme.qml`](../quickshell/Theme.qml), through two components:
`EaseOut {}` (a `NumberAnimation`) and `ColorFade {}` (a `ColorAnimation`). Don't type curves
or durations inline.

- **Curves:** `easeOut` (0.23, 1, 0.32, 1) for anything entering, leaving or responding;
  `easeInOut` (0.77, 0, 0.175, 1) for things moving across the screen (toggle knob, segmented
  pill, toast stack); plain `ease` for colour changes. **Never ease-in**: it starts slowly, which
  delays exactly the moment you are watching.
- **Durations:** UI stays under 300 ms. Press 120, hover 150, dropdown 180 (exit 140),
  resize 200, toast 250. Only ambient things are longer: wallpaper crossfade 1200, theme morph 400, and a dynamic
  wallpaper drifting to its next frame of the day 8000.
- **Exits are quicker than entrances.** Nobody waits on something leaving.
- **Nothing appears from nothing:** enter from `scale 0.96` + opacity, never from scale 0.

### Interruptible, from the current value

Use `Behavior`s and ListView transitions, not keyframe-style sequences, for anything that can be
retriggered (toggling a panel twice, a burst of notifications). They retarget from wherever the
value currently is instead of restarting.

### Spatial consistency

- A panel **grows out of the button that opened it**: `UiState.anchorX` records the button, and
  `PanelCard` scales from that point. Modals (polkit) are centred and scale from the centre.
- Things leave the way they came: toasts enter from the right and leave to the right; the OSD
  rises from below and sinks back.
- **Switching between open bar panels is instant**, like a menu bar: once one menu is open,
  moving to the next must not cost an animation. Hovering another bar button while a panel is
  open switches to it.
- Content that changes size inside an open card (networks found, a section toggled on) **resizes
  the card smoothly**, clipped so growth reads as a reveal. A different panel replacing it does not.

### Gestures

The notification swipe follows Apple's direct-manipulation rules: the card stays glued to the
pointer (keeping the grab offset), dragging the wrong way meets rubber-band resistance
(`over·w·0.55 / (w + 0.55·|over|)`), and on release the **velocity of the last ~100 ms**
decides: a flick dismisses, a slow drag past 40% that isn't heading back dismisses, anything else
returns home. A dismissing card continues at the speed it was thrown (velocity handoff). Sliders
keep the offset from where you grabbed the knob.

### Accessibility

`QS_REDUCE_MOTION=1` keeps fades and colour changes but drops movement and scaling (reduced
motion means gentler, not none). `QS_REDUCE_TRANSPARENCY=1` makes every frosted surface solid.

## 2. Surfaces and depth

- **One material:** floating surfaces (panels, launcher, OSD, polkit card, bar) are translucent
  `Theme.material` over a real compositor blur (`BackgroundEffect.blurRegion`, niri 26.04's
  ext-background-effect). The blur region follows the card's on-screen size, including mid-animation,
  and is dropped the moment a surface starts closing: blur can't fade, so tying it to opacity > 0
  leaves a bare frosted rectangle behind the fading card.
  niri layer rules turn off "xray" for overlays so they blur the windows beneath, not just the wallpaper.
- **One glass value per theme:** a preset's `barOpacity` sets the opacity of the bar, the panels
  and ghostty together (niri blurs behind ghostty via a window rule), so all glass matches.
- **Exceptions:** toasts and tooltips stay solid. They stack or sit over arbitrary content, and
  small text must stay readable.
- **Depth:** `Shadow {}` behind every floating surface, deeper for bigger ones (launcher and polkit
  1.4, panels 1, toasts and OSD 0.6, tooltips 0.4). A modal task (polkit, launcher) dims the screen;
  a parallel one (panels) doesn't.
- **One discreet 1 px border** (`Theme.border`), matching niri's window borders. The bar has none:
  as frosted glass it separates itself, and a hard divider only adds noise.
- **The bar is two floating pills, not a band** (2026-10-23): only the button groups are glass;
  the strip between them is clear so the wallpaper shows through and the bar reads lighter.
- **Window corners come from niri alone** (10 px, `clip-to-geometry`). Apps that draw their own
  rounded frame fight it (Chrome: turn on "Use system title bar and borders"). Translucent windows
  use `draw-border-with-background false`, or the inactive border colour fills in behind the glass.
- **niri sets the cursor theme** (`cursor {}`); shapes the shell asks for (crosshair, hand) need it.
- Scroll lists fade at the edge where content continues (`ScrollList`), instead of a hard cut.

## 3. Information and layout

- **The bar shows only what you need at a glance:** icons and the time. Percentages, network
  names, the full date and the hidden right-click actions live in **tooltips** (`BarTooltip`) and
  in the panels. The exceptions are states that matter at a glance: low battery shows its percentage,
  recording shows its timer, and a non-default keyboard layout shows its code.
- **Icon weight:** bar icons are Phosphor **fill** (`Theme.barIconWeight`): solid shapes read at a
  glance over any wallpaper. Everything inside panels, menus and the launcher is **bold**
  (`Theme.iconWeight`), which matches the weight of the text next to it.
- **Tooltips follow toolbar rules:** the first waits 500 ms and fades in; while one is up (or was,
  a moment ago) the next appears instantly with no animation. They are hidden while a bar panel is
  open and after a click.
- **Forgiveness without dialogs:** irreversible actions (power off, reboot, log out, forget a
  network, unpair a device) arm on the first click and show a red fuse draining over 3 s; a second
  click confirms. Use `ConfirmButton` for new ones; save real dialogs for real emergencies.
- **Validate inline:** e.g. Wi-Fi Connect stays dimmed until the password is long enough, with a hint.
- **Feedback on press:** pressables scale to 0.97 (big rows 0.98) on press, not on release.
  Colour changes of text and background fade together (no frame of dark text on a grey tile).

### Screenshots

PrtSc opens our picker (`ScreenshotOverlay.qml`), modelled on macOS: the screen freezes and dims,
you drag a region and the shot is taken on release (no extra confirm step), with the selection
undimmed and its size shown. A small toolbar (and keys: W window, Enter screen, Esc cancel) switches
to clicking a window or the whole screen. It appears instantly (keyboard). Window picking uses
niri's `pick-window`, because niri only reports positions for floating windows, so we cannot
hit-test tiled ones ourselves. Every screenshot is saved to ~/Pictures/Screenshots and its path
replaces the image on the clipboard (the image stays in clipboard history). The niri binds fall
back to niri's own tools if the shell is not running.

## 4. Typography

One font, Maple Mono NF. `StyledText` applies size-dependent tracking automatically: display
sizes (20 px and up) tighten by 2%, tiny labels (11 px and below) open by 0.2 px, body text is
untouched. All-caps section labels set their own wider tracking. Hierarchy comes from weight and
size together, not size alone.

## 5. Colour and theming

- Colours always come from `Theme` tokens (the active preset), never literals.
- Switching theme morphs every shell colour over 400 ms (a rare, deliberate action), and GTK apps
  recolour live: the `theme` command turns each preset into a small generated GTK theme
  (`~/.local/share/themes/theme-<id>-<hash>`), and the change of theme name is what makes running
  GTK3 apps and Chrome (Appearance > Theme > GTK) reload.

## Checklist for something new

1. How often will it be triggered, and by keyboard or pointer? Keyboard-frequent means no motion.
2. Use `EaseOut` / `ColorFade` and the `Theme` duration tokens; no ease-in; keep it under 300 ms;
   exits quicker than entrances.
3. Does it come from somewhere? Grow or slide from that place, and leave the same way.
4. Can it be retriggered mid-motion? Use a `Behavior` so it retargets.
5. Floating surface? `Theme.material` + a blur region + `Shadow {}` + `Theme.border`, or solid if
   it holds small text over arbitrary content.
6. Irreversible? `ConfirmButton`. Does it need explaining? A tooltip, not more text in the bar.
7. Check it with `QS_REDUCE_MOTION=1` and `QS_REDUCE_TRANSPARENCY=1`.

## Deliberately not done

- **No launcher open/close animation** (keyboard, many times a day). Only its depth (the dim
  and the shadow) settles in over ~150 ms behind the card, which is there instantly.
- **No auto-hiding bar** (removed 2026-10-19: unused, and a hidden bar adds a wait to every glance).
- **No bounce** in menus or panels; a spring overshoot is only right after a physical throw.
- **No animation when a panel's content swaps** to another panel (menu-bar rule).
