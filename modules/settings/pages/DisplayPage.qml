import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../services/DisplayModel.js" as Model

// Settings › Display: the displays as they are arranged, the selected one's
// details and brightness, and the desktop-wide text size and laptop panel.
// No Caelestia original (its nexus has a "Display" TODO stub); drawn with
// Nexus rows. Data and actions are DisplayService's (hyprmoncfg's daemon when
// it manages the displays, hyprctl otherwise; Omarchy's commands for the rest).
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  Component.onCompleted: DisplayService.hold()
  Component.onDestruction: DisplayService.release()

  // The draft while hyprmoncfg's editor is there (what Apply would set), the
  // live state otherwise.
  readonly property var monitors: DisplayService.editable ? DisplayService.draftRows : DisplayService.monitors
  readonly property bool edit: DisplayService.editable && !DisplayService.previewBusy
  readonly property string selected: DisplayService.selected   // survives Settings closing for the confirm card
  readonly property var sel: monitors.find(m => m.name === selected) || monitors.find(m => m.focused) || monitors[0] || null

  spacing: Tk.spacing.extraSmall / 2

  // ---- who manages the displays
  ConnectedRect {
    Layout.fillWidth: true
    first: true
    last: true
    implicitHeight: bl.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: bl
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon {
        text: DisplayService.backend === "hyprmoncfg" ? "verified" : "info"
        size: Tk.iconSize.medium
        color: DisplayService.backend === "hyprmoncfg" ? Colours.m3primary : Colours.m3onSurfaceVariant
      }
      RowLabel {
        Layout.fillWidth: true
        text: DisplayService.backend === "hyprmoncfg" ? "Managed by hyprmoncfg" + (DisplayService.activeProfile ? " · " + DisplayService.activeProfile : "")
          : DisplayService.backend === "unmanaged" ? "hyprmoncfg is installed but not managing the displays"
          : "Read from Hyprland"
        subtext: DisplayService.backend === "hyprmoncfg" ? "Layouts follow your displays on hotplug, lid and resume"
          : DisplayService.backend === "unmanaged" ? "Let it manage them to save layouts per set of displays"
          : "Arranging displays, modes and profiles need hyprmoncfg"
      }
      IconTextButton {
        visible: DisplayService.backend === "unmanaged"
        type: "tonal"
        isRound: true
        fontSize: Tk.body.small
        horizontalPadding: Tk.padding.medium
        verticalPadding: Tk.padding.extraSmall
        icon: "play_arrow"
        text: "Manage"
        onClicked: DisplayService.manage()
      }
    }
  }

  // ---- the arrangement
  SectionHeader { row: ({ text: "Arrangement" }) }
  ConnectedRect {
    id: canvasCard
    Layout.fillWidth: true
    first: true
    last: true
    implicitHeight: Tk.px(220)
    readonly property var fitted: Model.fit(root.monitors, width, height - Tk.px(40), Tk.padding.large)
    Repeater {
      model: Model.rects(root.monitors, canvasCard.fitted)
      Rectangle {
        required property var modelData
        readonly property bool isSel: root.sel && root.sel.name === modelData.name
        x: Math.round(modelData.x); y: Math.round(modelData.y)
        width: Math.round(modelData.w) - 4; height: Math.round(modelData.h) - 4
        radius: Tk.rounding.small
        color: isSel ? Colours.m3primaryContainer : Colours.m3surfaceContainerHighest
        border.width: isSel ? 2 : 1
        border.color: isSel ? Colours.m3primary : Colours.m3outlineVariant
        Behavior on color { CAnim {} }
        Column {
          anchors.centerIn: parent
          MText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; weight: Font.Medium; color: isSel ? Colours.m3onPrimaryContainer : Colours.m3onSurface }
          MText {
            readonly property var m: root.monitors.find(x => x.name === modelData.name)
            anchors.horizontalCenter: parent.horizontalCenter
            text: m ? m.width + "×" + m.height + " · " + Model.scaleLabel(m.scale) : ""
            font.pointSize: Tk.label.small
            color: Colours.m3onSurfaceVariant
          }
        }
        // Displays mirroring this one are left off the canvas (they'd sit
        // under it); a chip each, to select them.
        Column {
          z: 2
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Tk.padding.small
          spacing: Tk.spacing.extraSmall
          Repeater {
            model: root.monitors.filter(m => m.mirrorOf && (m.mirrorOf === modelData.key || m.mirrorOf === modelData.name)).map(m => m.name)
            IconTextButton {
              required property string modelData
              type: root.selected === modelData || (root.sel && root.sel.name === modelData) ? "filled" : "tonal"
              isRound: true
              icon: "screen_share"
              text: modelData + " mirrors this"
              fontSize: Tk.label.small
              verticalPadding: Tk.padding.extraSmall
              onClicked: DisplayService.selected = modelData
            }
          }
        }
        // Click selects; with the editor, drag moves it (the daemon snaps it
        // to its neighbours on edit_profile).
        MouseArea {
          id: boxMouse
          anchors.fill: parent
          cursorShape: root.edit ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
          drag.target: root.edit ? parent : null
          drag.threshold: Tk.px(6)
          onPressed: DisplayService.selected = modelData.name
          onReleased: {
            if (!drag.active && Math.abs(parent.x - Math.round(modelData.x)) < 1 && Math.abs(parent.y - Math.round(modelData.y)) < 1) return
            const at = Model.toLayout(parent.x, parent.y, canvasCard.fitted)
            DisplayService.edit(modelData.key, { x: at.x, y: at.y, snap_distance: Math.round(Tk.px(16) / canvasCard.fitted.k) })
            parent.x = Qt.binding(() => Math.round(modelData.x)); parent.y = Qt.binding(() => Math.round(modelData.y))
          }
        }
      }
    }
    IconTextButton {
      anchors.right: parent.right; anchors.bottom: parent.bottom
      anchors.margins: Tk.padding.small
      type: "tonal"
      isRound: true
      fontSize: Tk.body.small
      horizontalPadding: Tk.padding.medium
      verticalPadding: Tk.padding.extraSmall
      icon: "badge"
      text: "Identify"
      onClicked: DisplayService.identify()
    }
  }

  // ---- changes waiting for Apply
  ConnectedRect {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.small
    first: true
    last: true
    visible: DisplayService.dirty || DisplayService.lastError !== "" || DisplayService.previewBusy
    implicitHeight: ab.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: ab
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon {
        text: DisplayService.lastError ? "error" : "edit"
        size: Tk.iconSize.medium
        color: DisplayService.lastError ? Colours.m3error : Colours.m3primary
      }
      RowLabel {
        Layout.fillWidth: true
        text: DisplayService.lastError ? DisplayService.lastError
          : DisplayService.previewBusy ? "Waiting for you to keep or revert"
          : "Changes not applied yet"
        subtext: DisplayService.previewBusy ? "" : "Applied for 30 seconds first; kept in profile " + (DisplayService.sourceProfile || "Omacale") + " if you keep them"
      }
      IconTextButton {
        visible: DisplayService.dirty && !DisplayService.previewBusy
        type: "text"; isRound: true; icon: "undo"; text: "Reset"
        fontSize: Tk.body.small
        onClicked: DisplayService.reset()
      }
      IconTextButton {
        visible: DisplayService.dirty && !DisplayService.previewBusy
        type: "filled"; isRound: true; icon: "check"; text: "Apply"
        fontSize: Tk.body.small
        disabled: DisplayService.editPending
        onClicked: DisplayService.apply()
      }
    }
  }

  // ---- the selected display
  SectionHeader { visible: !!root.sel; row: ({ text: root.sel ? root.sel.name : "" }) }
  Repeater {
    model: root.sel && !DisplayService.editable ? [
      { label: "Model", value: root.sel.label },
      { label: "Resolution", value: root.sel.width + " × " + root.sel.height + " @ " + Math.round(root.sel.refresh) + " Hz" },
      { label: "Scale", value: Model.scaleLabel(root.sel.scale) + " · " + root.sel.lw + " × " + root.sel.lh + " logical" },
      { label: "Position", value: root.sel.x + ", " + root.sel.y + (root.sel.mirrorOf ? " · mirrors " + root.sel.mirrorOf : "") }
    ] : []
    ConnectedRect {
      required property var modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0
      last: index === 3 && brightRow.visible === false
      implicitHeight: il.implicitHeight + Tk.padding.medium * 2
      RowLayout {
        id: il
        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
        MText { Layout.fillWidth: true; text: modelData.label }
        MText { Layout.maximumWidth: parent.width / 2; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: modelData.value; color: Colours.m3onSurfaceVariant }
      }
    }
  }
  DisplayEditor {
    Layout.fillWidth: true
    visible: DisplayService.editable && !!root.sel
    sel: root.sel
    monitors: root.monitors
    settings: root.settings
    enabled: root.edit
    last: !brightRow.visible
  }
  ConnectedRect {
    id: brightRow
    readonly property var level: root.sel ? DisplayService.brightness[root.sel.name] : undefined
    visible: level !== undefined
    Layout.fillWidth: true
    last: true
    implicitHeight: br.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: br
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon { text: "brightness_6"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      MSlider {
        Layout.fillWidth: true
        implicitHeight: Tk.px(30)
        value: (brightRow.level || 0) / 100
        onMoved: v => DisplayService.setBrightness(root.sel.name, Math.max(1, v * 100))
      }
      MText { Layout.preferredWidth: Tk.px(40); horizontalAlignment: Text.AlignRight; text: Math.round(brightRow.level || 0) + "%"; color: Colours.m3onSurfaceVariant }
    }
  }

  // ---- this screen dark for now (DPMS), until "Turn on", a lock or a resume
  ConnectedRect {
    id: offRow
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.small
    first: true
    last: true
    visible: !!root.sel && root.sel.enabled
    readonly property bool off: !!root.sel && DisplayService.blanked.indexOf(root.sel.name) >= 0
    implicitHeight: bo.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: bo
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon { text: offRow.off ? "monitor" : "desktop_access_disabled"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      RowLabel {
        Layout.fillWidth: true
        text: offRow.off ? (root.sel ? root.sel.name : "") + " is off" : "Turn off for now"
        subtext: offRow.off ? "It stays dark until you turn it on here, lock the screen or resume"
          : root.sel && !DisplayService.canBlank(root.sel.name) ? "Another display has to stay on"
          : "The screen goes dark; your layout and windows stay as they are"
      }
      IconTextButton {
        type: offRow.off ? "filled" : "tonal"; isRound: true
        icon: "power_settings_new"
        text: offRow.off ? "Turn on" : "Turn off"
        fontSize: Tk.body.small
        disabled: !offRow.off && !(root.sel && DisplayService.canBlank(root.sel.name))
        onClicked: offRow.off ? DisplayService.wake(root.sel.name) : DisplayService.blank(root.sel.name)
      }
    }
  }

  DisplayProfiles {
    Layout.fillWidth: true
    visible: DisplayService.editable
  }
  DisplayWorkspaces {
    Layout.fillWidth: true
    visible: DisplayService.editable
    settings: root.settings
  }

  // ---- desktop-wide
  SectionHeader { row: ({ text: "All displays" }) }
  RowToggle {
    Layout.fillWidth: true
    first: true
    text: "Ask when a display is connected"
    subtext: "Opens Extend / Mirror / Only laptop / Only external (also on the optional display key, Settings › Keybinds)"
    checked: Config.o.display.quickOnConnect
    onToggled: c => Config.set("display.quickOnConnect", c)
  }
  RowToggle {
    id: linkRow
    Layout.fillWidth: true
    visible: Object.keys(DisplayService.brightness).length > 1
    text: "Same brightness on every display"
    subtext: "One brightness for all: the sliders and scrolling on the bar move every display together"
    checked: DisplayService.linked
    onToggled: c => Config.set("display.linkBrightness", c)
  }
  ConnectedRect {
    Layout.fillWidth: true
    first: !linkRow.visible
    last: !DisplayService.hasInternal || !DisplayService.hasExternal || DisplayService.editable
    implicitHeight: tl.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: tl
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      RowLabel { Layout.fillWidth: true; text: "Text size"; subtext: "Omarchy's text size for the shell, GTK and the terminal" }
      IconButton { type: "text"; icon: "remove"; disabled: DisplayService.textSize <= 9; onClicked: DisplayService.setTextSize(DisplayService.textSize - 1) }
      MText { Layout.preferredWidth: Tk.px(48); horizontalAlignment: Text.AlignHCenter; text: DisplayService.textSize ? DisplayService.textSize + " px" : "–" }
      IconButton { type: "text"; icon: "add"; disabled: DisplayService.textSize >= 20; onClicked: DisplayService.setTextSize(DisplayService.textSize + 1) }
    }
  }
  RowToggle {
    Layout.fillWidth: true
    visible: DisplayService.hasInternal && DisplayService.hasExternal && !DisplayService.editable
    text: "Laptop display"
    subtext: "Turn off to use only the external displays"
    checked: root.monitors.some(m => m.internal && m.enabled)
    onToggled: c => DisplayService.setInternal(c)
  }
  RowToggle {
    Layout.fillWidth: true
    visible: DisplayService.hasInternal && DisplayService.hasExternal && !DisplayService.editable
    last: true
    text: "Mirror the laptop display"
    subtext: "Show the same picture on the external display"
    checked: root.monitors.some(m => !!m.mirrorOf)
    onToggled: c => DisplayService.setMirror(c)
  }

  // ---- night light (services/NightLight.qml): Omarchy's hyprsunset, every screen
  SectionHeader { row: ({ text: "Night light" }) }
  RowToggle {
    Layout.fillWidth: true
    first: true
    text: "Night light"
    subtext: "Warmer colours on every display (hyprsunset can't tint one screen alone)"
    checked: NightLight.on
    onToggled: c => NightLight.set(c)
  }
  ConnectedRect {
    Layout.fillWidth: true
    implicitHeight: nt.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: nt
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon { text: "thermostat"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      MText { text: "Warmth"; Layout.preferredWidth: Tk.px(70) }
      MSlider {
        id: warmth
        Layout.fillWidth: true
        implicitHeight: Tk.px(30)
        // Left is warm: the slider runs 6000 K -> 2500 K.
        value: 1 - Model.kelvinPos(Config.o.display.nightTemp)
        onMoved: v => NightLight.setTemperature(Model.kelvinAt(1 - v))
      }
      MText { Layout.preferredWidth: Tk.px(56); horizontalAlignment: Text.AlignRight; text: Config.o.display.nightTemp + " K"; color: Colours.m3onSurfaceVariant }
    }
  }
  RowSelect {
    Layout.fillWidth: true
    last: Config.o.display.nightSchedule !== "custom"
    settings: root.settings
    row: ({ key: "display.nightSchedule", label: "Schedule", icon: "schedule",
      subtext: Config.o.display.nightSchedule === "sun" ? (Sys.sunsetIso ? "Sunset " + Sys.sunset + " to sunrise " + Sys.sunrise + ", from the weather location" : "Needs the weather (Language & region › weather location)") : "A manual switch holds until the schedule's next change",
      options: [{ value: "off", label: "Off" }, { value: "sun", label: "Sunset to sunrise" }, { value: "custom", label: "Custom times" }] })
  }
  RowSelect {
    Layout.fillWidth: true
    visible: Config.o.display.nightSchedule === "custom"
    settings: root.settings
    row: ({ key: "display.nightFrom", label: "From", icon: "bedtime", options: root.halfHours })
  }
  RowSelect {
    Layout.fillWidth: true
    visible: Config.o.display.nightSchedule === "custom"
    last: true
    settings: root.settings
    row: ({ key: "display.nightTo", label: "To", icon: "wb_sunny", options: root.halfHours })
  }
  readonly property var halfHours: [{ value: "00:00", label: "00:00" }, { value: "00:30", label: "00:30" }, { value: "01:00", label: "01:00" }, { value: "01:30", label: "01:30" }, { value: "02:00", label: "02:00" }, { value: "02:30", label: "02:30" }, { value: "03:00", label: "03:00" }, { value: "03:30", label: "03:30" }, { value: "04:00", label: "04:00" }, { value: "04:30", label: "04:30" }, { value: "05:00", label: "05:00" }, { value: "05:30", label: "05:30" }, { value: "06:00", label: "06:00" }, { value: "06:30", label: "06:30" }, { value: "07:00", label: "07:00" }, { value: "07:30", label: "07:30" }, { value: "08:00", label: "08:00" }, { value: "08:30", label: "08:30" }, { value: "09:00", label: "09:00" }, { value: "09:30", label: "09:30" }, { value: "10:00", label: "10:00" }, { value: "10:30", label: "10:30" }, { value: "11:00", label: "11:00" }, { value: "11:30", label: "11:30" }, { value: "12:00", label: "12:00" }, { value: "12:30", label: "12:30" }, { value: "13:00", label: "13:00" }, { value: "13:30", label: "13:30" }, { value: "14:00", label: "14:00" }, { value: "14:30", label: "14:30" }, { value: "15:00", label: "15:00" }, { value: "15:30", label: "15:30" }, { value: "16:00", label: "16:00" }, { value: "16:30", label: "16:30" }, { value: "17:00", label: "17:00" }, { value: "17:30", label: "17:30" }, { value: "18:00", label: "18:00" }, { value: "18:30", label: "18:30" }, { value: "19:00", label: "19:00" }, { value: "19:30", label: "19:30" }, { value: "20:00", label: "20:00" }, { value: "20:30", label: "20:30" }, { value: "21:00", label: "21:00" }, { value: "21:30", label: "21:30" }, { value: "22:00", label: "22:00" }, { value: "22:30", label: "22:30" }, { value: "23:00", label: "23:00" }, { value: "23:30", label: "23:30" }]
}
