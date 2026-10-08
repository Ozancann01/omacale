# Changelog

Omashell is a fork of [Omacale](https://github.com/AyushKr2003/omacale) by [AyushKr2003](https://github.com/AyushKr2003). Everything up to 0.45.4 is Omacale as AyushKr2003 made it; the versions below are what this fork adds. Each version has a [release on GitHub](https://github.com/Ozancann01/omashell/releases).

## 0.63.0 — One Taskbar, Omarchy's widgets

- **Settings › Taskbar is one list of everything in the bar**: Omashell's items, Omarchy's own widgets and plugins, each with a chip saying where it comes from, an eye, its settings and a remove button in the same columns. The plugin pill's widgets sit under it and can be dragged out for a place of their own or back in. The separate Layout and Bar plugins pages are gone; Logo and Power share a small page.
- **Omarchy's own bar widgets in Omashell's bar**: the AI agents usage panel, weather and indicators are put on the bar as on Omarchy's own, and "Add a widget" lists the rest by category (media, Tailscale, Dropbox, ...; switched-off ones are turned on when added). Omarchy's versions of things Omashell already draws (volume, network, clock, ...) are behind a switch.
- **Omarchy updates**: a bar widget a new Omarchy adds is put on the bar by itself (before the power button), marked New in Settings, with a toast. A widget that no longer loads takes no room and its row says why. A placed Omarchy widget answers its own panel hotkey.
- **A chevron for anything**: drag any item (status icons, Omarchy widgets, plugins) into "Behind the chevron" in Settings › Taskbar, and/or set "Show at most N icons" to tuck the rest away. Hovering or clicking the chevron opens them inside the same pill. Plugins that were behind the plugin pill's own chevron move there.
- **Neighbouring icons share one pill**: status icons, widgets, the plugin pill, the tray and the power button next to each other are drawn as one group instead of separate pills. A power button on its own stays a bare icon.

## 0.62.0 — Omashell

- **New name: Omashell.** Plugin `omashell.bar`, command and IPC `omashell` (`omarchy-shell omashell …`), settings in `~/.config/omashell`, state in `~/.local/state/omashell`.
- **Moving over from Omacale is automatic**: `./install.sh` copies your settings and state, points your Hyprland binds and the `omacale.lua` include at Omashell, switches the bar in `shell.json`, and rebuilds the notification, OSD and lock-screen hand-overs. Everything it changes is backed up in `~/.local/state/omashell/` first; the old plugin folder is kept there too.
- Credit to Omacale and AyushKr2003 in the README, Settings › About and the plugin manifest.

## 0.61.0 — One Display section

- Every screen setting now lives in **Settings › Display**: the main page shows the arrangement and the selected screen (Advanced folded away), and sub-pages hold Profiles, Workspaces, Brightness, Night light, Shell on each screen and Text and cursor, each with a live status line.
- Taskbar, Desktop, Notifications and OSD link there instead of keeping their own screen settings.
- Settings pages open at the top; unapplied display changes survive moving between sub-pages.

## 0.60.0 — Workspaces per screen

- Choose which workspaces live on which screen: Manual (click a workspace to move it), Sequential or Interleaved, with the plan per screen shown. Saved in the profile, applied with the same keep-or-revert.

## 0.59.0 — Night light

- Night light with a warmth slider (6000 K to 2500 K) and a schedule: sunset to sunrise from your weather location, or custom times. A manual switch holds until the next change of the schedule.
- The utilities night-light toggle shows the real state again.

## 0.58.0 — Turn a screen off, brightness keys

- **Turn off for now**: darken one screen while the others stay on, without changing the layout, until you turn it back on, lock or resume.
- Optional brightness-key binds that move every screen together when they share one brightness.

## 0.57.0 — Display menu

- **Extend / Mirror / Only laptop / Only external**, like Win+P: `omarchy-shell omashell display menu`, optional laptop display key or Super+P bind, or by itself when a screen is plugged in. Goes through the keep-or-revert card.

## 0.56.0 — Profiles

- hyprmoncfg's saved layouts in Settings: apply one (keep or revert), delete, save the current layout under a name, automatic switching on or off.
- Details per screen: connector, serial, size, pixel density, colour format, workspace.

## 0.55.0 — One brightness for every screen

- "Same brightness on every screen": one slider (and the bar's scroll) moves every screen together.
- Brightness changes are no longer lost while a slow external monitor (DDC) is still applying the previous one.

## 0.54.x — Change your screens

- Resolution, refresh rate, scale (sharp scales, one marked recommended), rotation, mirroring, variable refresh, colour and bit depth, and drag the screens into place; **Apply** tries it for 30 seconds behind a "Keep these display settings?" card on every screen and reverts by itself, even if the shell is gone. Needs hyprmoncfg, which stays the only writer of your monitor config.
- 0.54.1: long dropdown menus stay inside Settings and scroll.
- 0.54.2: a mirroring screen can be selected and un-mirrored.

## 0.53.0 — Settings › Display

- See how your screens are arranged, Identify labels on every screen, a brightness slider per screen (external ones over DDC), Omarchy's text size, a cursor size that matches on every screen. The utilities drawer gets a Displays card, and scrolling on a bar changes its own screen's brightness.

## 0.52.0 — Per-screen shell

- Choose per screen whether it has a bar and on which edge, and where the desktop clock, notifications and OSD show.

## 0.51.0 — Omarchy's menus in your colours

- Opt-in: Omarchy's own menus, popups and notifications in Omashell's Material colours (a marked, removable block in `shell.toml`).

## 0.50.0 — Colours that match the theme

- Light or dark exactly as Omarchy decides it, and the Omarchy palette taken from the theme's own panel colours.

## 0.49.0 — Pickers everywhere, theme from your wallpaper

- Omashell's wallpaper and theme carousels from every entry point, and **From wallpaper** builds a whole Omarchy theme from your wallpaper (with aether).

## 0.48.0 — Session menu

- Super+Esc and the power key can open the session drawer (falling back to Omarchy's menu when locked or not running), with Lock and Screensaver buttons and your own picture.

## 0.47.0 — Bar layout

- Drag any bar item between start, center and end, take items off the bar and add them back (Settings › Taskbar › Layout).

## 0.46.0 — Hide plugin widgets

- Each third-party bar widget can be pinned, kept behind the chevron, or hidden from the bar.

## 0.45.4 — Omacale, the starting point

Omacale as made by [AyushKr2003](https://github.com/AyushKr2003/omacale): the Caelestia-style frame, bar, drawers, launcher, dashboard, notifications, OSD, lock screen, overview, plugin manager and settings app that Omashell is built on.
