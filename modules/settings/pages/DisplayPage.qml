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

  readonly property var monitors: DisplayService.monitors
  property string selected: ""
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
        StateLayer { onClicked: root.selected = modelData.name }
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

  // ---- the selected display
  SectionHeader { visible: !!root.sel; row: ({ text: root.sel ? root.sel.name : "" }) }
  Repeater {
    model: root.sel ? [
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

  // ---- desktop-wide
  SectionHeader { row: ({ text: "All displays" }) }
  ConnectedRect {
    Layout.fillWidth: true
    first: true
    last: !DisplayService.hasInternal || !DisplayService.hasExternal
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
    visible: DisplayService.hasInternal && DisplayService.hasExternal
    text: "Laptop display"
    subtext: "Turn off to use only the external displays"
    checked: root.monitors.some(m => m.internal && m.enabled)
    onToggled: c => DisplayService.setInternal(c)
  }
  RowToggle {
    Layout.fillWidth: true
    visible: DisplayService.hasInternal && DisplayService.hasExternal
    last: true
    text: "Mirror the laptop display"
    subtext: "Show the same picture on the external display"
    checked: root.monitors.some(m => !!m.mirrorOf)
    onToggled: c => DisplayService.setMirror(c)
  }
}
