import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Boot menu › Picture: an image behind Limine's menu, picked with
// Omacale's own FileDialog (Settings.fileRequested), as Session › Picture.
// Only the path is kept here; Apply copies the file onto the boot partition
// (Limine can't read anything else).
ConnectedRect {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property string path: Config.o.boot.wallpaper
  implicitHeight: rl.implicitHeight + Tk.padding.medium * 2

  RowLayout {
    id: rl
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.medium
    spacing: Tk.spacing.medium
    Rectangle {
      Layout.preferredWidth: Tk.iconSize.large * 2
      Layout.preferredHeight: Math.round(Layout.preferredWidth * 9 / 16)
      radius: Tk.rounding.extraSmall
      color: Colours.m3surfaceContainerHighest
      clip: true
      Image {
        anchors.fill: parent
        visible: root.path !== ""
        source: root.path ? "file://" + root.path : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 256
        asynchronous: true
      }
      MIcon { anchors.centerIn: parent; visible: root.path === ""; text: "hide_image"; color: Colours.m3onSurfaceVariant }
    }
    RowLabel {
      Layout.fillWidth: true
      text: "Picture"
      subtext: root.path ? root.path.slice(root.path.lastIndexOf("/") + 1) + " · copied to the boot partition when you apply"
        : "None: the background colour fills the screen. PNG, JPEG or BMP, up to 16 MB"
    }
    IconButton {
      visible: root.path !== ""
      type: "text"
      icon: "close"
      onClicked: Config.set("boot.wallpaper", "")
    }
    IconButton {
      type: "tonal"
      icon: "folder_open"
      onClicked: root.settings.fileRequested("Select a boot menu picture", ["png", "jpg", "jpeg", "bmp"], p => {
        Config.set("boot.wallpaper", p)
        // Over a picture an opaque text background would hide it: start
        // half see-through, as Limine's own default with a wallpaper.
        if (Config.o.boot.backgroundAlpha === 0) Config.set("boot.backgroundAlpha", 50)
      })
    }
  }
}
