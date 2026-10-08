import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../core/BarLayout.js" as BarLayout

// Settings › Taskbar: a small picture of the bar, always drawn as a row
// whatever edge the real one is on, from the same layout the list below
// edits -- start, center and end, neighbours sharing a pill as on the bar,
// the chevron closed with a count of what is behind it. Clicking an icon
// asks the page to show its row (`picked`). No Caelestia original.
Rectangle {
  id: root
  required property var layout
  // The page, for isShown(id) (its eye switch, a widget being on) and iconOf(id).
  required property var page
  signal picked(string id)

  readonly property var rendered: {
    const r = BarLayout.render(layout, Config.o.bar.layout.maxShown, id => root.page.isShown(id))
    const out = {}
    for (const s of BarLayout.SECTIONS) out[s] = r[s].filter(x => !x.drawer && root.page.isShown(x.id)).map(x => x.id)
    return out
  }
  readonly property int behind: {
    const r = BarLayout.render(layout, Config.o.bar.layout.maxShown, id => root.page.isShown(id))
    let n = 0
    for (const s of BarLayout.SECTIONS) n += r[s].filter(x => x.drawer && root.page.isShown(x.id)).length
    return n
  }
  readonly property real cell: Tk.iconSize.medium + Tk.padding.medium

  implicitHeight: barRect.implicitHeight + Tk.padding.large * 2
  radius: Tk.rounding.large
  color: Colours.m3surfaceContainer

  Rectangle {
    id: barRect
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: Tk.padding.large
    implicitHeight: root.cell + Tk.padding.small * 2
    radius: height / 2
    color: Colours.m3surface

    Zone { anchors.left: parent.left; anchors.leftMargin: Tk.padding.small; anchors.verticalCenter: parent.verticalCenter; ids: root.rendered.start }
    Zone { anchors.centerIn: parent; ids: root.rendered.center }
    Zone { anchors.right: parent.right; anchors.rightMargin: Tk.padding.small; anchors.verticalCenter: parent.verticalCenter; ids: root.rendered.end }
  }

  // One section: its groups side by side, a pill behind each joined group.
  component Zone: Row {
    id: zone
    property var ids: []
    spacing: Tk.spacing.small
    Repeater {
      model: BarLayout.groups(zone.ids)
      Rectangle {
        id: grp
        required property var modelData
        readonly property bool pill: modelData.pill && modelData.ids.length > 0
        width: icons.implicitWidth + (pill ? Tk.padding.small * 2 : 0)
        height: root.cell
        radius: height / 2
        color: pill ? Colours.m3surfaceContainerHigh : "transparent"
        Row {
          id: icons
          anchors.centerIn: parent
          Repeater {
            model: grp.modelData.ids
            Item {
              id: cellItem
              required property string modelData
              readonly property bool isClock: modelData === "clock"
              width: isClock ? clockText.implicitWidth + Tk.padding.small : root.cell
              height: root.cell
              MIcon {
                visible: !cellItem.isClock
                anchors.centerIn: parent
                // The chevron as the bar draws it on a row: pointing where its items come out.
                text: cellItem.modelData === "overflow"
                  ? (root.layout.end.indexOf("overflow") >= 0 ? "chevron_left" : "chevron_right")
                  : root.page.iconOf(cellItem.modelData)
                size: Tk.iconSize.medium
                color: cellItem.modelData === "power" ? Colours.m3error : Colours.m3onSurfaceVariant
              }
              MText {
                id: clockText
                visible: cellItem.isClock
                anchors.centerIn: parent
                text: Qt.formatTime(new Date(), "HH:mm")
                font.pointSize: Tk.body.small
                color: Colours.m3onSurfaceVariant
              }
              // How many are behind the chevron.
              Rectangle {
                visible: cellItem.modelData === "overflow" && root.behind > 0
                anchors.right: parent.right
                anchors.top: parent.top
                width: Math.max(height, badge.implicitWidth + Tk.padding.extraSmall)
                height: badge.implicitHeight
                radius: height / 2
                color: Colours.m3primary
                MText { id: badge; anchors.centerIn: parent; text: root.behind; font.pointSize: Tk.label.small * 0.8; color: Colours.m3onPrimary }
              }
              StateLayer { radius: width / 2; onClicked: root.picked(cellItem.modelData) }
            }
          }
        }
      }
    }
  }
}
