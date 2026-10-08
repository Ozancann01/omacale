pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
// HyprLook: keeps Hyprland's gaps and window rounding in step with Omashell's
// UI scale. No Omarchy command sets them, and omashell.lua is where Omashell's
// Hyprland styling lives, so the numbers are worked out there
// (omashell_scaled): this only hands it the spacing scale and the frame's
// corner radius.
//
//   - $XDG_STATE_HOME/omashell/hypr.lua holds them, and omashell.lua reads it on
//     every load, so they survive `hyprctl reload` and a restart.
//   - `hyprctl eval "omashell_apply(...)"` applies a change at once. It is a
//     no-op when omashell.lua isn't loaded (the function doesn't exist), so a
//     user who doesn't load it keeps their own Hyprland look.
QtObject {
  id: root

  readonly property real spacing: Number(Tk.spaceScale.toFixed(4))
  readonly property int frameRounding: Tk.borderRounding
  // Settings › Display › Cursor (omashell.lua's omashell_display).
  readonly property int cursorSize: Config.o.display.cursorSize
  readonly property string zeroScaling: Config.o.display.zeroScaling
  readonly property string args: spacing + " " + frameRounding + " " + cursorSize + " " + zeroScaling

  // omashell.lua's 1x values and its rule, for Settings to show what Hyprland
  // should be running. Keep in step with omashell_scaled.
  function scaled(name, base, gapsOutBase) {
    const px = n => Math.round(n * root.spacing)
    if (name === "windowRounding") return Math.max(0, root.frameRounding - px(gapsOutBase))
    if (["windowGapsIn", "windowGapsOut", "workspaceGaps", "singleWindowGapsOut"].indexOf(name) >= 0) return px(base)
    return base
  }

  // Coalesce a slider's burst of changes into one write.
  onArgsChanged: push.restart()
  Component.onCompleted: push.restart()
  property Timer push: Timer {
    interval: 400
    onTriggered: {
      if (root.apply.running) { restart(); return }
      root.apply.running = true
    }
  }
  property Process apply: Process {
    command: ["bash", "-c", `
      d="\${XDG_STATE_HOME:-$HOME/.local/state}/omashell"
      mkdir -p "$d" || exit 1
      printf -- '-- Written by Omashell (services/HyprLook.qml), read by omashell.lua.\\nreturn { spacing = %s, frameRounding = %s, cursorSize = %s, zeroScaling = "%s" }\\n' "$1" "$2" "$3" "$4" > "$d/hypr.lua.tmp" \\
        && mv "$d/hypr.lua.tmp" "$d/hypr.lua"
      hyprctl eval "if omashell_apply then omashell_apply({ spacing = $1, frameRounding = $2, cursorSize = $3, zeroScaling = \\"$4\\" }) end" >/dev/null 2>&1 || true
      # A cursor size of the user's own, at once: Hyprland's cursor and GTK's.
      # The size it replaces is kept, so going back to 0 restores it live
      # (the env vars in omashell.lua only reach the next session).
      size="$3"
      if [ "$size" -gt 0 ]; then
        [ -f "$d/cursor-size.orig" ] || gsettings get org.gnome.desktop.interface cursor-size > "$d/cursor-size.orig" 2>/dev/null
      elif [ -f "$d/cursor-size.orig" ]; then
        size=$(cat "$d/cursor-size.orig"); rm -f "$d/cursor-size.orig"
      else
        size=0
      fi
      if [ "\${size:-0}" -gt 0 ] 2>/dev/null; then
        theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
        hyprctl setcursor "\${theme:-default}" "$size" >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface cursor-size "$size" 2>/dev/null || true
      fi
    `, "hyprlook", String(root.spacing), String(root.frameRounding), String(root.cursorSize), root.zeroScaling]
  }
}
