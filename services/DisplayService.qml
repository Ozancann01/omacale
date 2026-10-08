pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."
import "DisplayModel.js" as Model

// Settings › Display and the utilities Displays card. No Caelestia original
// (its nexus has only a TODO stub "Display"). The displays come from
// hyprmoncfg's daemon when it manages them -- the only writer of monitor
// config then, so Omacale never writes monitors.lua or its profiles -- and
// from hyprctl otherwise; brightness, text size and the laptop panel are
// Omarchy's own commands. Connected only while something shows displays
// (hold/release), so it costs nothing otherwise.
QtObject {
  id: root

  // ---------------------------------------------------------- holders
  property int holds: 0
  function hold() { holds++; if (holds === 1) start() }
  function release() { holds = Math.max(0, holds - 1); if (holds === 0) stop() }

  // "hyprmoncfg": its daemon manages the displays; "unmanaged": installed but
  // not managing (daemon off, or `hyprmoncfg unmanage`); "none": not there.
  property string backend: "none"
  property var monitors: []
  property string activeProfile: ""
  readonly property bool hasInternal: monitors.some(m => m.internal)
  readonly property bool hasExternal: monitors.some(m => !m.internal)

  function start() { probe.running = true; hyprRead.running = true; brightnessRead() ; textRead.running = true }
  function stop() { sock.connected = false; reconnect.stop() }

  property Process probe: Process {
    command: ["sh", "-c", "command -v hyprmoncfg >/dev/null || exit 3; systemctl --user is-active --quiet hyprmoncfgd.service || exit 4; exit 0"]
    onExited: code => {
      if (code === 3) root.backend = "none"
      else if (code === 4) root.backend = "unmanaged"
      else { root.backend = "hyprmoncfg"; sock.connected = true }
    }
  }

  // ------------------------------------------------- hyprmoncfg socket
  property int seq: 0
  property var methods: ({})             // request id -> method, for its response
  function send(method, params) {
    if (!sock.connected) return ""
    seq++
    methods[String(seq)] = method
    sock.write(Model.request(seq, method, params))
    sock.flush()
    return String(seq)
  }
  function onStatus(status) {
    if (!status) return
    if (status.daemon && status.daemon.unmanaged) { backend = "unmanaged"; return }
    const m = Model.fromStatus(status)
    if (m.length) monitors = m
    activeProfile = status.active_profile ? status.active_profile.name || "" : ""
    syncPreview(status.daemon ? status.daemon.preview : null)
    // The live layout moved (hotplug, a profile switch, a kept preview):
    // follow it, unless the user is in the middle of an edit.
    if (!dirty && !editPending && !previewBusy) loadEditor()
  }
  function onResponse(e) {
    const method = methods[String(e.id)] || ""
    delete methods[String(e.id)]
    if (e.error) {
      lastError = String(e.error.message || "hyprmoncfg couldn't do that")
      if (method === "edit_profile") { editPending = false; editQueue = []; }
      if (method === "preview") { endPreview(); previewPending = false }
      if (method === "commit" || method === "revert") actionPending = false
      return
    }
    const r = e.result || {}
    if (method === "editor_state") onEditor(r)
    else if (method === "edit_profile") { draft = r.profile || draft; editPending = false; pump() }
    else if (method === "preview") {
      transactionId = String(r.id || "")
      deadline = String(r.deadline || "")
      if (transactionId) previewFile.write(transactionId)
      else endPreview()
      previewPending = false
    }
    else if (method === "commit" || method === "revert") { actionPending = false; endPreview(); loadEditor() }
    else if (r.monitors) onStatus(r)
  }
  property Socket sock: Socket {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/hyprmoncfgd.sock"
    connected: false
    parser: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        const e = Model.parseEnvelope(line)
        if (!e) return
        if (e.type === "event" && e.event === "status") root.onStatus(e.data)
        else if (e.type === "response") root.onResponse(e)
      }
    }
    onConnectedChanged: {
      if (connected) { root.send("subscribe", {}); root.loadEditor() }
      else if (root.holds > 0 && root.backend === "hyprmoncfg") reconnect.restart()
    }
    onError: connected = false
  }
  // The daemon restarting (or busy) drops the socket; try again shortly.
  property Timer reconnect: Timer { interval: 750; onTriggered: if (root.holds > 0) root.probe.running = true }

  // ------------------------------------------------- hyprctl fallback
  property Process hyprRead: Process {
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.backend === "hyprmoncfg" && root.sock.connected && root.monitors.length) return
        try { root.monitors = Model.fromHypr(JSON.parse(text)) } catch (e) {}
      }
    }
  }
  property Connections hyprEvents: Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (root.holds > 0 && ["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].indexOf(e.name) >= 0) {
        root.hyprRead.running = true
        root.brightnessRead()
      }
    }
  }

  // ------------------------------------------------------- brightness
  // Per display, through Omarchy (backlight, or DDC/CI on an external one).
  // A display that reports none (no backlight, no DDC) gets no slider.
  property var brightness: ({})          // name -> 0..100
  function brightnessRead() {
    const names = Quickshell.screens.map(s => s.name)
    brightRead.command = ["sh", "-c", 'for m in "$@"; do printf "%s\\t%s\\n" "$m" "$(omarchy-brightness-display --monitor "$m" 2>/dev/null)"; done', "read"].concat(names)
    brightRead.running = true
  }
  property Process brightRead: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        const out = {}
        for (const line of text.split("\n")) {
          const [name, v] = line.split("\t")
          if (name && /^\d+$/.test((v || "").trim())) out[name] = Number(v)
        }
        root.brightness = out
      }
    }
  }
  function setBrightness(name, value) {
    const b = Object.assign({}, brightness)
    b[name] = Math.round(value)
    brightness = b
    Quickshell.execDetached(["omarchy-brightness-display", "--no-osd", "--monitor", name, Math.round(value) + "%"])
  }

  // -------------------------------------------------------- text size
  property int textSize: 0
  property Process textRead: Process {
    command: ["omarchy-display-text-size"]
    stdout: StdioCollector {
      onStreamFinished: { const m = /text size:\s*(\d+)/.exec(text); if (m) root.textSize = Number(m[1]) }
    }
  }
  function setTextSize(px) {
    textSize = px
    Quickshell.execDetached(["omarchy-display-text-size", String(px)])
  }

  // ------------------------------------------------- laptop panel / mirror
  function setInternal(on) { Quickshell.execDetached(["omarchy-hyprland-monitor-internal", on ? "on" : "off"]); later.restart() }
  function setMirror(on) { Quickshell.execDetached(["omarchy-hyprland-monitor-internal-mirror", on ? "on" : "off"]); later.restart() }
  property Timer later: Timer { interval: 900; onTriggered: root.hyprRead.running = true }

  // Let hyprmoncfg manage the displays (its own plugin's "manage").
  function manage() {
    Quickshell.execDetached(["sh", "-c", "systemctl --user enable --now hyprmoncfgd.service && hyprmoncfg manage"])
    reconnect.restart()
  }

  // ----------------------------------------------------------- editing
  // Only with hyprmoncfg: Omacale edits a copy of the live profile through
  // the daemon (edit_profile is pure; it snaps and reflows, and applies
  // nothing), then hands the result to `preview`. The daemon applies it,
  // owns the 30-second revert deadline (so a crashed shell still reverts),
  // and saves it into the profile on Keep. Omacale never writes a profile.
  property var editorDoc: null
  property var draft: null
  property string savedSig: ""
  property string sourceProfile: ""
  readonly property var draftRows: Model.fromEditor(draft ? { profile: draft, displays: editorDoc ? editorDoc.displays : [] } : null)
  readonly property bool editable: backend === "hyprmoncfg" && sock.connected && !!draft
  readonly property bool dirty: !!draft && Model.signature(draft) !== savedSig
  property bool editPending: false
  property var editQueue: []
  property string lastError: ""
  property string selected: ""            // Settings › Display's selected display

  function loadEditor() { if (backend === "hyprmoncfg") send("editor_state", {}) }
  function onEditor(doc) {
    if (!doc || !doc.profile) return
    editorDoc = doc
    sourceProfile = String(doc.source_profile || "")
    draft = JSON.parse(JSON.stringify(doc.profile))
    savedSig = Model.signature(doc.profile)
  }
  // Edits go one at a time, each on the draft the previous one returned.
  function edit(key, fields) {
    if (!editable || previewBusy) return
    lastError = ""
    editQueue = editQueue.concat([Object.assign({ output_key: key }, fields)])
    pump()
  }
  function pump() {
    if (editPending || !editQueue.length) return
    const next = editQueue[0]
    editQueue = editQueue.slice(1)
    editPending = true
    if (send("edit_profile", { profile: draft, edit: next }) === "") { editPending = false; editQueue = [] }
  }
  function reset() {
    lastError = ""
    editQueue = []
    if (editorDoc) { draft = JSON.parse(JSON.stringify(editorDoc.profile)) }
  }

  // ------------------------------------------------- preview / keep / revert
  property string transactionId: ""
  property string deadline: ""
  property bool previewPending: false
  property bool actionPending: false
  readonly property bool previewBusy: previewPending || transactionId !== ""
  readonly property bool confirming: transactionId !== "" && !reclaiming
  property int seconds: 0
  property Timer clock: Timer {
    running: root.confirming
    repeat: true
    interval: 250
    triggeredOnStart: true
    onTriggered: root.seconds = Model.secondsLeft(root.deadline, Date.now())
  }

  // Saved into the profile it came from (a new "Omacale" profile if the
  // layout matched none) when kept; PR 8 adds naming and choosing profiles.
  function apply() {
    if (!editable || !dirty || previewBusy) return
    lastError = ""
    fromSettings = true
    const profile = JSON.parse(JSON.stringify(draft))
    profile.name = sourceProfile || "Omacale"
    previewPending = true
    hold()                              // stay connected until it is kept or reverted
    if (send("preview", { profile: profile, timeout_seconds: 30, save_on_commit: true }) === "") {
      previewPending = false
      lastError = "hyprmoncfg isn't reachable"
      release()
    }
  }
  function keep() {
    if (!confirming || actionPending) return
    actionPending = true
    if (send("commit", { transaction_id: transactionId, save: true }) === "") actionPending = false
  }
  function revert() {
    if (!confirming || actionPending) return
    actionPending = true
    if (send("revert", { transaction_id: transactionId }) === "") actionPending = false
  }
  // The daemon's status says whether our preview still runs; once it is gone
  // (timed out and reverted, or kept/reverted from elsewhere) the card goes.
  function syncPreview(p) {
    if (!transactionId) return
    if (Model.ownsPreview(p, transactionId)) { reclaiming = false; if (p.deadline) deadline = String(p.deadline) }
    else if (!actionPending) { endPreview(); loadEditor() }
  }
  // The card takes the keyboard, which closes Settings (its focus grab is
  // cleared); Bar.qml opens Settings › Display again once it's answered.
  signal previewEnded(bool fromSettings)
  property bool fromSettings: false
  function endPreview() {
    if (transactionId !== "" || previewPending) previewEnded(fromSettings)
    fromSettings = false
    const held = transactionId !== "" || previewPending   // apply() and a reclaim each hold once
    transactionId = ""
    deadline = ""
    actionPending = false
    reclaiming = false
    previewFile.clear()
    if (held) release()
  }

  // The preview's id, kept in $XDG_RUNTIME_DIR so a shell restarted during
  // the countdown asks again (only about Omacale's own preview).
  readonly property string previewPath: Quickshell.env("XDG_RUNTIME_DIR") + "/omacale-display-preview"
  property bool reclaiming: false
  property QtObject previewFile: QtObject {
    function write(id) { Quickshell.execDetached(["sh", "-c", 'printf %s "$1" > "$2"', "w", id, root.previewPath]) }
    function clear() { Quickshell.execDetached(["rm", "-f", root.previewPath]) }
  }
  // hyprmoncfg's own Omarchy plugin confirms every preview whose client went
  // away ("reclaimable"), so with it installed a restarted shell leaves the
  // question to it rather than putting a second card over it.
  property Process previewRead: Process {
    running: true
    command: ["sh", "-c", 'id=$(cat "$1" 2>/dev/null) || exit 0; if [ -d "$2" ]; then rm -f "$1"; else printf %s "$id"; fi',
      "read", root.previewPath, Quickshell.env("HOME") + "/.config/omarchy/plugins/crmne.hyprmoncfg"]
    stdout: StdioCollector {
      onStreamFinished: {
        const id = text.trim()
        if (!id) return
        root.reclaiming = true
        root.transactionId = id          // syncPreview drops it if it's over
        root.hold()
      }
    }
  }

  // ---------------------------------------------------------- identify
  // A big name on each screen for a moment (modules/display/DisplayIdentify).
  property bool identifying: false
  function identify() { identifying = true; identifyTimer.restart() }
  property Timer identifyTimer: Timer { interval: 2500; onTriggered: root.identifying = false }
}
