import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Boot menu: a picture of Limine's menu with the page's settings,
// drawn here (the real one is only seen at boot). Roughly Limine's layout on a
// 1920x1080 screen: its 8x16 font with 1px spacing, the branding centred on
// the first line, the help line under it, the entries at the left, and the
// terminal inset 64px over a wallpaper (term_margin's default then).
Item {
  id: root
  property var settings
  property var row
  property bool first
  property bool last

  readonly property var c: Config.o.boot
  function col(v, fallback) { return /^[0-9a-fA-F]{6}$/.test(v) ? "#" + v : fallback }
  readonly property color fg: col(c.foreground, "#c0caf5")
  readonly property color bg: col(c.background, "#1a1b26")
  readonly property color brand: col(c.brandingColor, "#9ece6a")
  readonly property bool hasWall: c.wallpaper !== ""
  readonly property real s: width / 1920
  readonly property real cw: 9 * s
  readonly property real ch: 16 * s

  Layout.fillWidth: true
  implicitHeight: Math.round(width * 9 / 16)

  Rectangle {
    id: screen
    anchors.fill: parent
    radius: Tk.rounding.large
    color: root.hasWall ? root.col(root.c.backdrop, "#000000") : root.bg
    clip: true

    Image {
      anchors.fill: parent
      visible: root.hasWall
      source: root.hasWall ? "file://" + root.c.wallpaper : ""
      fillMode: root.c.wallpaperStyle === "tiled" ? Image.Tile : root.c.wallpaperStyle === "centered" ? Image.Pad : Image.Stretch
      // Centered and tiled draw the picture at its own size, so at the
      // preview's scale too.
      sourceSize.width: root.c.wallpaperStyle === "stretched" ? 1024 : undefined
      transform: Scale { xScale: root.c.wallpaperStyle === "stretched" ? 1 : root.s; yScale: xScale; origin.x: screen.width / 2; origin.y: screen.height / 2 }
      asynchronous: true
    }

    // The terminal: the whole screen without a wallpaper, inset over one.
    Rectangle {
      id: term
      readonly property real m: root.hasWall ? 64 * root.s : 0
      x: m; y: m; width: parent.width - 2 * m; height: parent.height - 2 * m
      color: root.bg
      opacity: root.hasWall ? 1 - Math.max(0, Math.min(100, root.c.backgroundAlpha)) / 100 : 1
    }
    Item {
      x: term.x; y: term.y; width: term.width; height: term.height
      Text {
        y: root.ch * 0.5
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.c.branding || "Omarchy Bootloader"
        color: root.brand
        font.family: Tk.mono; font.pixelSize: Math.max(4, root.ch * 0.95)
      }
      Text {
        visible: !root.c.hideHelp
        y: root.ch * 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: "ARROWS Select    ENTER Boot    E Edit    B Browse"
        color: root.brand
        font.family: Tk.mono; font.pixelSize: Math.max(4, root.ch * 0.95)
      }
      Column {
        x: root.cw * 4
        y: root.ch * 4.5
        spacing: root.ch * 0.25
        Repeater {
          model: [{ t: "v Omarchy", sel: false }, { t: "    linux-omarchy", sel: true }, { t: "  > Snapshots", sel: false }]
          Rectangle {
            required property var modelData
            width: entryText.implicitWidth + root.cw
            height: root.ch * 1.1
            color: modelData.sel ? root.fg : "transparent"
            Text {
              id: entryText
              anchors.verticalCenter: parent.verticalCenter
              x: root.cw / 2
              text: parent.modelData.t
              color: parent.modelData.sel ? root.bg : root.fg
              font.family: Tk.mono; font.pixelSize: Math.max(4, root.ch * 0.95)
            }
          }
        }
      }
      Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.ch
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Booting automatically in " + (root.c.timeout > 0 ? root.c.timeout : 5) + ", press any key to stop."
        color: root.fg
        font.family: Tk.mono; font.pixelSize: Math.max(4, root.ch * 0.95)
      }
    }
    MText {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tk.padding.small
      text: "Preview"
      font.pointSize: Tk.label.small
      color: "white"
      opacity: 0.6
    }
  }
}
