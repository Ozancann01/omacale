import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../core/BarLayout.js" as BarLayout

// Settings › Taskbar's bar: everything in it, in one list per section
// (bar.layout), Noctalia-style; no Caelestia original. Omashell's own items,
// Omarchy's widgets and third-party plugins are rows alike, told apart by a
// chip. Rows are dragged by their handle to any place in any section, into
// "Not in the bar" to take them off it, and back out to add them again. The
// plugin pill's widgets sit indented under it and can be dragged out of it
// for a place of their own, or back in. The eye is the item's existing switch
// (Status icons › Network, Clock › Show, ...): hidden, an item keeps its
// place; the gear opens its own settings. Widgets not in the bar at all are
// under "Add a widget", grouped by their category.
//
// The page is an Item rather than a layout so the dragged row's ghost and
// the drop line can float above the rows.
Item {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  implicitHeight: col.implicitHeight
  // The widget list (names, categories, which are enabled) comes from Omarchy.
  Component.onCompleted: PluginService.refresh()
  // New marks last until the page is left.
  Component.onDestruction: PluginService.clearFresh()

  readonly property var layout: {
    const l = Config.o.bar.layout
    void l.start; void l.center; void l.end; void l.removed
    void PluginService.barWidgets
    return PluginService.barLayout()
  }
  readonly property bool vertical: Tk.barVertical
  // "pill" is the plugin pill's own rows, checked first so a drop over them
  // lands in the pill rather than in the section around it.
  readonly property var lists: ["pill"].concat(BarLayout.SECTIONS).concat(["removed"])
  readonly property var pillIds: PluginService.pillWidgets.map(p => p.id)
  readonly property var placed: BarLayout.SECTIONS.concat(["removed"]).reduce((out, s) =>
    out.concat(root.layout[s].filter(id => BarLayout.isPlugin(id)).map(id => BarLayout.pluginOf(id))), [])
  // Third-party widgets still in the pill, in the order the pill shows them.
  readonly property var pillMembers: PluginService.pillWidgets.filter(p => root.placed.indexOf(p.id) < 0).map(p => "plugin:" + p.id)
  readonly property bool pillOnBar: BarLayout.SECTIONS.some(s => root.layout[s].indexOf("plugins") >= 0)

  function title(list) { return list === "removed" ? "Not in the bar" : BarLayout.sectionLabel(list, vertical) }

  // A row's facts, built-in or widget.
  function info(id) {
    if (BarLayout.isPlugin(id)) {
      const pid = BarLayout.pluginOf(id)
      const p = PluginService.byId(pid)
      const err = PluginService.widgetErrors[pid] || ""
      const source = p && p.firstParty ? "omarchy" : "plugin"
      return {
        label: p ? p.name : pid, icon: BarLayout.categoryIcon(p ? p.category : ""), source: source,
        sub: err ? "Couldn't load: " + err : (p && p.description ? p.description : (source === "omarchy" ? "Omarchy widget" : "Plugin")),
        error: err !== "", key: "", page: "", plugin: true, pluginId: pid,
        inPill: root.pillIds.indexOf(pid) >= 0, fresh: Config.o.bar.layout.fresh.indexOf(pid) >= 0
      }
    }
    const it = BarLayout.ITEMS[id] || { label: id, icon: "help", key: "", sub: "" }
    return {
      label: id === "plugins" ? "Plugin pill" : it.label, icon: it.icon, source: "omashell",
      sub: id === "plugins" ? (root.pillMembers.length ? "Third-party widgets, together" : "Empty: no third-party widgets") : it.sub,
      error: false, key: it.key, page: BarLayout.PAGES[id] || "", plugin: false, pluginId: "", inPill: false, fresh: false
    }
  }
  function openSettings(it) {
    if (it.plugin) { root.settings.selectedPlugin = it.pluginId; root.settings.push("pluginInfo") }
    else if (it.page) root.settings.push(it.page)
  }
  function place(id, list, index) { PluginService.placeItem(id, list, index) }
  // "Add to" menu for a row: every section but the one it is in.
  function addOptions(from) {
    return BarLayout.SECTIONS.filter(s => s !== from).map(s => ({ value: s, label: title(s), icon: s === "start" ? "first_page" : s === "end" ? "last_page" : "horizontal_distribute" }))
  }

  // ------------------------------------------------------------- add list
  // Every bar widget that is nowhere in the bar: not placed, not in the pill
  // (third-party ones that are on are always there), not taken off. Omarchy's
  // versions of Omashell's own items only with the switch on.
  readonly property var addable: {
    void Config.o.bar.layout.removed
    const dup = Config.o.bar.layout.showDuplicates
    return PluginService.widgetCatalog.filter(p =>
      root.placed.indexOf(p.id) < 0 && !(p.source === "plugin" && p.enabled)
      && (dup || p.duplicateOf === null))
  }
  // [{ category, items }] sorted by category, then name.
  readonly property var addGroups: {
    const by = {}
    for (const p of root.addable) {
      const c = p.category || "Other"
      ;(by[c] = by[c] || []).push(p)
    }
    return Object.keys(by).sort().map(c => ({ category: c, items: by[c].sort((a, b) => a.name.localeCompare(b.name)) }))
  }
  readonly property int duplicateCount: PluginService.widgetCatalog.filter(p => p.duplicateOf !== null && root.placed.indexOf(p.id) < 0).length

  // ------------------------------------------------------------- drag
  property string dragId: ""
  property string dragLabel: ""
  property string dragIcon: ""
  property real dragY: 0         // pointer, in root coordinates
  property real grabDy: 0        // pointer's offset into the row it grabbed
  property real rowH: 0
  property string dropList: ""
  property int dropIndex: -1
  property real lineY: 0
  property var sections: ({})    // list -> its section column

  // The settings page's scroll view, for scrolling while dragging near its edge.
  readonly property Item flick: { let f = root.parent; while (f && f.contentY === undefined) f = f.parent; return f }
  property real flickPointer: 0  // pointer, in the scroll view's coordinates

  // Only a third-party widget can go into the pill.
  function canDrop(list) {
    if (list !== "pill") return true
    return BarLayout.isPlugin(dragId) && pillIds.indexOf(BarLayout.pluginOf(dragId)) >= 0
  }
  function rowsIn(list) {
    const s = sections[list]
    return s ? s.rowItems().filter(r => r.modelData !== dragId) : []
  }
  function startDrag(row, pointerY) {
    const top = row.mapToItem(root, 0, 0).y
    dragId = row.modelData
    dragLabel = row.it.label
    dragIcon = row.it.icon
    rowH = row.height
    grabDy = pointerY - top
    moveDrag(pointerY)
  }
  function moveDrag(pointerY) {
    dragY = pointerY
    if (flick) flickPointer = root.mapToItem(flick, 0, pointerY).y
    // The section the pointer is over, or the nearest one.
    let best = "", bestD = Infinity
    for (const l of lists) {
      const s = sections[l]
      if (!s || !s.visible || !canDrop(l)) continue
      const top = s.mapToItem(root, 0, 0).y, bottom = top + s.height
      const d = pointerY < top ? top - pointerY : pointerY > bottom ? pointerY - bottom : 0
      if (d < bestD) { bestD = d; best = l }
    }
    dropList = best
    if (!best) return
    const rows = rowsIn(best)
    let i = 0
    for (const r of rows) if (pointerY > r.mapToItem(root, 0, 0).y + r.height / 2) i++
    dropIndex = i
    const gap = col.spacing
    if (!rows.length) {
      const s = sections[best]
      // Just above the empty section's hint, not through its text.
      lineY = s.emptyItem().mapToItem(root, 0, 0).y - gap / 2 - 1
    } else if (i < rows.length) lineY = rows[i].mapToItem(root, 0, 0).y - gap / 2 - 1
    else { const r = rows[rows.length - 1]; lineY = r.mapToItem(root, 0, 0).y + r.height + gap / 2 - 1 }
  }
  function endDrag() {
    if (dragId && dropList === "pill") PluginService.putBackWidget(BarLayout.pluginOf(dragId))
    else if (dragId && dropList) place(dragId, dropList, dropIndex)
    cancelDrag()
  }
  function cancelDrag() { dragId = ""; dropList = ""; dropIndex = -1 }

  // Near the scroll view's top or bottom edge the page scrolls under the
  // pointer, and the drop place follows.
  Timer {
    interval: 16
    repeat: true
    running: root.dragId !== "" && !!root.flick
    onTriggered: {
      const f = root.flick, edge = Tk.px(48)
      const step = root.flickPointer < edge ? -Tk.px(10) : root.flickPointer > f.height - edge ? Tk.px(10) : 0
      if (!step) return
      const max = Math.max(0, f.contentHeight - f.height + (f.bottomMargin || 0))
      const before = f.contentY
      f.contentY = Math.max(-(f.topMargin || 0), Math.min(max, f.contentY + step))
      if (f.contentY !== before) root.moveDrag(root.mapFromItem(f, 0, root.flickPointer).y)
    }
  }

  // A row of the bar: handle, icon, name and chip, and its actions.
  component BarRow: ConnectedRect {
    id: r
    required property string modelData
    property bool off: false       // in "Not in the bar"
    property bool child: false     // a widget inside the plugin pill
    readonly property var it: root.info(modelData)
    readonly property string mode: it.inPill ? PluginService.barMode(it.pluginId) : ""
    // The eye: a built-in's existing switch; a pill widget's hidden mode.
    readonly property bool isShown: child ? mode !== "hidden" : it.plugin ? true : PluginService.itemShown(modelData)
    readonly property bool dim: off || !isShown || it.error
    Layout.fillWidth: true
    Layout.leftMargin: child ? Tk.padding.extraLarge : 0
    implicitHeight: rl.implicitHeight + Tk.padding.small * 2
    opacity: root.dragId === modelData ? 0.3 : 1
    color: child ? Colours.m3surfaceContainerLow : Colours.m3surfaceContainer

    RowLayout {
      id: rl
      anchors.fill: parent
      anchors.topMargin: Tk.padding.small
      anchors.bottomMargin: Tk.padding.small
      anchors.leftMargin: Tk.padding.small
      anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium

      // The drag handle.
      MouseArea {
        Layout.preferredWidth: Tk.iconSize.medium + Tk.padding.small * 2
        Layout.fillHeight: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        onPressed: m => root.startDrag(r, mapToItem(root, m.x, m.y).y)
        onPositionChanged: m => { if (pressed) root.moveDrag(mapToItem(root, m.x, m.y).y) }
        onReleased: root.endDrag()
        onCanceled: root.cancelDrag()
        MIcon { anchors.centerIn: parent; text: "drag_indicator"; size: Tk.iconSize.medium; color: Colours.m3outline }
      }
      MIcon {
        text: r.it.error ? "error" : r.it.icon
        size: Tk.iconSize.medium
        color: r.it.error ? Colours.m3error : Colours.m3onSurfaceVariant
        opacity: r.dim && !r.it.error ? 0.45 : 1
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        opacity: r.dim && !r.it.error ? 0.45 : 1
        RowLayout {
          Layout.fillWidth: true
          spacing: Tk.spacing.small
          MText { Layout.fillWidth: false; Layout.maximumWidth: rl.width / 2; text: r.it.label; font.pointSize: Tk.body.small; elide: Text.ElideRight }
          SourceChip { source: r.it.source }
          SourceChip { visible: r.it.fresh; source: "new" }
          Item { Layout.fillWidth: true }
        }
        MText {
          Layout.fillWidth: true
          text: r.off ? "Not in the bar" : r.child && r.mode === "overflow" ? "Behind the pill's chevron"
            : !r.isShown ? "Hidden" : r.it.sub
          color: r.it.error ? Colours.m3error : Colours.m3outline
          font.pointSize: Tk.label.small
          elide: Text.ElideRight
        }
      }
      // Three fixed columns (eye, settings, remove), so the buttons line up
      // down the list whichever a row has.
      ActionSlot {
        shown: !r.off && (r.child || (!r.it.plugin && !!r.it.key))
        icon: r.isShown ? "visibility" : "visibility_off"
        onClicked: r.child ? PluginService.setBarMode(r.it.pluginId, r.isShown ? "hidden" : "pinned")
          : PluginService.setItemShown(r.modelData, !r.isShown)
      }
      ActionSlot {
        id: moreBtn
        shown: r.child || r.it.plugin || r.it.page !== ""
        icon: r.child ? "more_vert" : "settings"
        onClicked: {
          if (!r.child) { root.openSettings(r.it); return }
          root.settings.openMenu(moreBtn, moreBtn, [
            { value: "pinned", label: "Always in the pill", icon: "push_pin" },
            { value: "overflow", label: "Behind the chevron", icon: "expand_less" },
            { value: "out", label: "A place of its own", icon: "open_in_new" },
            { value: "info", label: "About this plugin", icon: "info" }
          ], r.mode, v => {
            if (v === "out") PluginService.takeOutWidget(r.it.pluginId)
            else if (v === "info") root.openSettings(r.it)
            else PluginService.setBarMode(r.it.pluginId, v)
          })
        }
      }
      ActionSlot {
        id: lastBtn
        // Off the bar (a third-party widget back into the pill instead), or,
        // in "Not in the bar", back onto it.
        shown: !r.child
        icon: r.off ? "add" : r.it.inPill ? "move_down" : "delete"
        onClicked: {
          if (r.off) root.settings.openMenu(lastBtn, lastBtn, root.addOptions(""), "",
            v => root.place(r.modelData, v, (root.layout[v] || []).length))
          else if (r.it.inPill) PluginService.putBackWidget(r.it.pluginId)
          else root.place(r.modelData, "removed", 0)
        }
      }
    }
  }

  // One of a row's action columns: keeps its room when the row has no such action.
  component ActionSlot: Item {
    id: slot
    property bool shown: true
    property string icon
    signal clicked()
    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight
    IconButton {
      id: btn
      visible: slot.shown
      type: "text"
      icon: slot.icon
      onClicked: slot.clicked()
    }
  }

  // Where a row comes from: Omashell, Omarchy or a plugin (or "new").
  component SourceChip: Rectangle {
    property string source
    readonly property var look: ({
      omashell: { text: "Omashell", bg: Colours.m3primaryContainer, fg: Colours.m3onPrimaryContainer },
      omarchy: { text: "Omarchy", bg: Colours.m3tertiaryContainer, fg: Colours.m3onTertiaryContainer },
      plugin: { text: "Plugin", bg: Colours.m3secondaryContainer, fg: Colours.m3onSecondaryContainer },
      "new": { text: "New", bg: Colours.m3primary, fg: Colours.m3onPrimary }
    })[source] || { text: source, bg: Colours.m3surfaceContainerHigh, fg: Colours.m3onSurface }
    implicitWidth: chipText.implicitWidth + Tk.padding.small * 2
    implicitHeight: chipText.implicitHeight + Tk.padding.extraSmall
    radius: height / 2
    color: look.bg
    MText {
      id: chipText
      anchors.centerIn: parent
      text: parent.look.text
      color: parent.look.fg
      font.pointSize: Tk.label.small
      weight: Font.Medium
    }
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Tk.spacing.extraSmall / 2

    Repeater {
      model: BarLayout.SECTIONS.concat(["removed"])

      ColumnLayout {
        id: sec
        required property string modelData
        required property int index
        readonly property var ids: modelData === "removed" ? root.layout.removed : root.layout[modelData]
        Layout.fillWidth: true
        spacing: Tk.spacing.extraSmall / 2
        Component.onCompleted: { const m = root.sections; m[modelData] = sec; root.sections = m }
        function rowItems() {
          const out = []
          for (let i = 0; i < rowsRep.count; i++) { const d = rowsRep.itemAt(i); if (d) out.push(d.row) }
          return out
        }
        function emptyItem() { return empty }

        // The sections are sub-headings of the page's "Bar" (or, for "Not in
        // the bar", a heading of its own).
        SectionHeader { visible: sec.modelData === "removed"; row: ({ text: root.title(sec.modelData) }) }
        MText {
          visible: sec.modelData !== "removed"
          Layout.topMargin: sec.index === 0 ? 0 : Tk.spacing.small
          Layout.leftMargin: Tk.padding.small
          text: root.title(sec.modelData)
          color: Colours.m3onSurfaceVariant
          font.pointSize: Tk.label.medium
          weight: Font.Medium
        }
        MText {
          id: empty
          Layout.fillWidth: true
          // Also the drop target of an empty section, so it keeps its room while dragging.
          visible: sec.ids.length === 0 || (sec.ids.length === 1 && sec.ids[0] === root.dragId)
          text: sec.modelData === "removed" ? "Everything is on the bar. Drag an item here to take it off."
            : "Empty. Drag an item here."
          color: Colours.m3outline
          wrapMode: Text.WordWrap
        }

        Repeater {
          id: rowsRep
          model: sec.ids

          // A row, and under the plugin pill's row the widgets in it.
          ColumnLayout {
            id: entry
            required property string modelData
            required property int index
            readonly property Item row: mainRow
            readonly property bool hasPill: modelData === "plugins" && sec.modelData !== "removed" && root.pillMembers.length > 0
            Layout.fillWidth: true
            spacing: Tk.spacing.extraSmall / 2

            BarRow {
              id: mainRow
              modelData: entry.modelData
              off: sec.modelData === "removed"
              first: entry.index === 0
              last: entry.index === rowsRep.count - 1 && !entry.hasPill
            }
            ColumnLayout {
              id: pillRows
              visible: entry.hasPill
              Layout.fillWidth: true
              spacing: Tk.spacing.extraSmall / 2
              Component.onCompleted: if (entry.modelData === "plugins") { const m = root.sections; m.pill = pillRows; root.sections = m }
              Component.onDestruction: if (root.sections.pill === pillRows) { const m = root.sections; delete m.pill; root.sections = m }
              function rowItems() {
                const out = []
                for (let i = 0; i < pillRep.count; i++) { const d = pillRep.itemAt(i); if (d) out.push(d) }
                return out
              }
              function emptyItem() { return pillRows }
              Repeater {
                id: pillRep
                model: entry.hasPill ? root.pillMembers : []
                BarRow {
                  required property int index
                  child: true
                  first: false
                  last: entry.index === rowsRep.count - 1 && index === pillRep.count - 1
                }
              }
            }
          }
        }
      }
    }

    // ----------------------------------------------------------- add list
    SectionHeader { row: ({ text: "Add a widget" }) }
    MText {
      Layout.fillWidth: true
      visible: root.addGroups.length === 0
      text: PluginService.loaded ? "Every widget is on the bar or under Not in the bar." : "Reading the widgets..."
      color: Colours.m3outline
      wrapMode: Text.WordWrap
    }
    Repeater {
      model: root.addGroups
      ColumnLayout {
        id: grp
        required property var modelData
        Layout.fillWidth: true
        spacing: Tk.spacing.extraSmall / 2
        MText {
          Layout.topMargin: Tk.spacing.small
          Layout.leftMargin: Tk.padding.small
          text: grp.modelData.category
          color: Colours.m3onSurfaceVariant
          font.pointSize: Tk.label.medium
          weight: Font.Medium
        }
        Repeater {
          id: addRep
          model: grp.modelData.items
          ConnectedRect {
            id: ar
            required property var modelData
            required property int index
            readonly property bool busy: PluginService.busyId === modelData.id
            Layout.fillWidth: true
            first: index === 0
            last: index === addRep.count - 1
            implicitHeight: al.implicitHeight + Tk.padding.small * 2
            StateLayer { disabled: ar.busy || PluginService.busyId !== ""; onClicked: PluginService.addWidget(ar.modelData.id) }
            RowLayout {
              id: al
              anchors.fill: parent
              anchors.topMargin: Tk.padding.small
              anchors.bottomMargin: Tk.padding.small
              anchors.leftMargin: Tk.padding.largeIncreased
              anchors.rightMargin: Tk.padding.medium
              spacing: Tk.spacing.medium
              MIcon { text: BarLayout.categoryIcon(ar.modelData.category); size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                  spacing: Tk.spacing.small
                  MText { text: ar.modelData.name; font.pointSize: Tk.body.small }
                  SourceChip { source: ar.modelData.source }
                }
                MText {
                  Layout.fillWidth: true
                  text: (ar.modelData.duplicateOf !== null ? "Omarchy's version of an Omashell item. " : "")
                    + (ar.modelData.enabled ? "" : "Off: adding turns it on. ") + (ar.modelData.description || "")
                  color: Colours.m3outline
                  font.pointSize: Tk.label.small
                  elide: Text.ElideRight
                }
              }
              MIcon { text: ar.busy ? "hourglass_top" : "add"; size: Tk.iconSize.medium; color: Colours.m3primary }
            }
          }
        }
      }
    }
    RowToggle {
      Layout.fillWidth: true
      Layout.topMargin: Tk.spacing.small
      visible: root.duplicateCount > 0 || Config.o.bar.layout.showDuplicates
      first: true
      last: true
      text: "Show Omarchy's versions of Omashell items"
      subtext: "Its own volume, network, clock, ... widgets, to use instead of or beside Omashell's"
      checked: Config.o.bar.layout.showDuplicates
      onToggled: c => Config.set("bar.layout.showDuplicates", c)
    }
    MText {
      Layout.fillWidth: true
      visible: PluginService.error !== ""
      text: PluginService.error
      color: Colours.m3error
      wrapMode: Text.WordWrap
    }

    // Reset, confirmed by a second click as Settings › About's "Reset all settings".
    SectionHeader { row: ({ text: "More" }) }
    ConnectedRect {
      Layout.fillWidth: true
      first: true
      last: true
      color: root.confirmReset ? Colours.m3errorContainer : Colours.m3surfaceContainer
      implicitHeight: rr.implicitHeight + Tk.padding.medium * 2
      StateLayer {
        color: Colours.m3error
        onClicked: {
          if (root.confirmReset) { PluginService.resetBarLayout(); root.confirmReset = false }
          else { root.confirmReset = true; confirmTimer.restart() }
        }
      }
      RowLayout {
        id: rr
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.medium
        MIcon { text: root.confirmReset ? "warning" : "restart_alt"; size: Tk.iconSize.medium; fill: 1; color: Colours.m3error }
        RowLabel {
          Layout.fillWidth: true
          text: root.confirmReset ? "Click again to reset the bar" : "Reset the bar"
          subtext: "Every item back where it was, plugins back in the pill, Omarchy's widgets as on its own bar"
        }
      }
    }
  }
  property bool confirmReset: false
  Timer { id: confirmTimer; interval: 3000; onTriggered: root.confirmReset = false }

  // The dragged row, following the pointer.
  Rectangle {
    visible: root.dragId !== ""
    z: 10
    x: 0
    width: root.width
    y: root.dragY - root.grabDy
    height: root.rowH
    radius: Tk.rounding.small
    color: Colours.m3surfaceContainerHighest
    border.width: 1
    border.color: Colours.m3primary
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tk.padding.small
      anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon { Layout.preferredWidth: Tk.iconSize.medium + Tk.padding.small * 2; horizontalAlignment: Text.AlignHCenter; text: "drag_indicator"; size: Tk.iconSize.medium; color: Colours.m3primary }
      MIcon { text: root.dragIcon; size: Tk.iconSize.medium; color: Colours.m3onSurface }
      MText { Layout.fillWidth: true; text: root.dragLabel; color: Colours.m3onSurface }
    }
  }
  // Where it will land.
  Rectangle {
    visible: root.dragId !== "" && root.dropList !== ""
    // Above the dragged row, which is under the pointer right where it lands.
    z: 11
    x: Tk.padding.small
    width: root.width - Tk.padding.small * 2
    y: root.lineY
    height: 3
    radius: 1.5
    color: Colours.m3primary
  }
}
