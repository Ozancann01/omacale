-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Omashell keybindings — paste into ~/.config/hypr/bindings.lua           │
-- │  Each action is an IPC call into the running Omarchy shell:             │
-- │  omarchy-shell omashell <launcher|dashboard|session|settings|close>      │
-- │  Keys below are unbound in a stock Omarchy install. Check yours with:   │
-- │  omarchy menu keybindings --print                                       │
-- ╰─────────────────────────────────────────────────────────────────────────╯

-- ── Helpers ─────────────────────────────────────────────────────────────────
-- o.rebind is provided by Omarchy (default/hypr/helpers.lua); restated here so
-- this file is self-contained when pasted. Same arguments as o.bind.

function o.rebind(keys, description, dispatcher, options)
  hl.unbind(keys)
  o.bind(keys, description, dispatcher, options)
end

-- ── Drawers ─────────────────────────────────────────────────────────────────

o.bind("SUPER + A", "Omashell launcher", "omarchy-shell omashell launcher")
o.bind("SUPER + D", "Omashell dashboard", "omarchy-shell omashell dashboard")
o.bind("SUPER + N", "Omashell notifications sidebar", "omarchy-shell omashell sidebar")
o.bind("SUPER + U", "Omashell quick toggles", "omarchy-shell omashell utilities")
o.bind("SUPER + SHIFT + ESCAPE", "Omashell session menu", "omarchy-shell omashell session")
o.bind("SUPER + SHIFT + I", "Omashell settings", "omarchy-shell omashell settings")

-- ── Dashboard tabs ──────────────────────────────────────────────────────────

o.bind("SUPER + ALT + D", "Omashell media", "omarchy-shell omashell dashboardTab media")
o.bind("SUPER + ALT + P", "Omashell performance", "omarchy-shell omashell dashboardTab performance")

-- ── Keyboard ────────────────────────────────────────────────────────────────
-- Omarchy's own SUPER + CTRL + A/B/W/P and 1..9 already open Omashell's popouts
-- (1..9 count the third-party widgets in the plugin pill). This one is the
-- bar focus mode: the bar takes the keyboard and a cursor walks its items --
-- j/k or arrows move, Enter/Space act, Menu or Shift+F10 opens a tray item's
-- menu, 1..9 switch workspace, Escape leaves. code:19 is the 0 key, which
-- Omarchy's code:10..18 loop leaves free.

o.bind("SUPER + CTRL + code:19", "Omashell bar focus", "omarchy-shell omashell barFocus")

-- Any bar popout straight from a key, opened with the keyboard (again closes
-- it). Omarchy's letters already cover network, bluetooth, power and audio;
-- these are the ones it has no key for (Y and U are free in a stock Omarchy;
-- check with: omarchy menu keybindings --print). Remove the "--" to use them.
-- o.bind("SUPER + CTRL + Y", "Omashell keyboard layouts", "omarchy-shell omashell popout kblayout")
-- o.bind("SUPER + CTRL + U", "Omashell pending update", "omarchy-shell omashell popout update")

-- ── Frame ───────────────────────────────────────────────────────────────────
-- SUPER + SHIFT + SPACE ("Toggle top bar") already hides/shows Omashell's
-- frame too; Omashell follows Omarchy's bar-off toggle.

-- ── Optional: make Omashell the main launcher ────────────────────────────────
-- These replace Omarchy defaults, so they are commented out. Remove the
-- leading "--" to use them. The picker binds open the launcher's carousel, or
-- Omarchy's own menu when Settings › Keybinds › Picker says "Omarchy default".
-- o.rebind("SUPER + SPACE", "Omashell launcher", "omarchy-shell omashell launcher")           -- was: Omarchy menu
-- ...or give the same key the Omarchy menu itself, drawn by Omashell (the ":"
-- prefix the launcher opens on). Pick one of these two, not both.
-- o.rebind("SUPER + SPACE", "Omashell menu", "omarchy-shell omashell menu")                   -- was: Omarchy menu
-- Session: Omashell's session drawer for the System-menu key and the power key, or
-- Omarchy's menu when Settings › Session › Menu says so, while the screen is locked,
-- or if Omashell is not running ("||": omarchy-shell fails when its target is missing).
-- o.rebind("SUPER + ESCAPE", "Omashell System menu", "omarchy-shell omashell session || omarchy-menu toggle system")      -- was: System menu
-- o.rebind("XF86PowerOff", "Omashell power menu", "omarchy-shell omashell session || omarchy-menu toggle system", { locked = true })  -- was: Power menu
-- o.rebind("SUPER + CTRL + SPACE", "Omashell wallpaper picker", "omarchy-shell omashell wallpapers")       -- was: Background switcher
-- o.rebind("SUPER + SHIFT + CTRL + SPACE", "Omashell theme picker", "omarchy-shell omashell themes")       -- was: Theme menu
-- o.rebind("SUPER + TAB", "Omashell workspace overview", "omarchy-shell omashell overview")                -- was: Next workspace
-- Clipboard history in the launcher. Omarchy's clipboard plugin keeps recording it either way.
-- o.rebind("SUPER + CTRL + V", "Omashell clipboard", "omarchy-shell omashell clipboard")                    -- was: Clipboard manager
-- Displays: Extend / Mirror / Only laptop / Only external (Settings › Display). The laptop's
-- display key, and/or Super+P as on other desktops (it replaces Omarchy's pseudo-tile bind).
-- o.bind("XF86Display", "Omashell display menu", "omarchy-shell omashell display menu")
-- o.rebind("SUPER + P", "Omashell display menu", "omarchy-shell omashell display menu")          -- was: Pseudo window
-- Brightness keys that move every display together when Settings › Display › "Same brightness
-- on every display" is on (otherwise the focused one, as Omarchy's do).
-- o.rebind("XF86MonBrightnessUp", "Omashell brightness up", "omarchy-shell omashell brightness +5% || omarchy-brightness-display +5%", { locked = true, repeating = true })    -- was: Brightness up
-- o.rebind("XF86MonBrightnessDown", "Omashell brightness down", "omarchy-shell omashell brightness 5%- || omarchy-brightness-display 5%-", { locked = true, repeating = true })  -- was: Brightness down
-- Details and actions for the focused window (also the chevron in the bar's active-window popout).
-- o.bind("SUPER + ALT + I", "Omashell window info", "omarchy-shell omashell windowInfo")
