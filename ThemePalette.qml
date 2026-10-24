import QtQuick
import Quickshell.Io
import qs.Commons

QtObject {
  id: root

  property var values: ({})

  readonly property color brightForeground: values.bright_foreground || Color.foreground
  readonly property color darkBackground: values.dark_background || Color.background
  readonly property color lighterBackground: values.lighter_background || Color.background

  readonly property string signature: [Color.foreground, Color.background, Color.accent, Color.muted, Color.urgent].join()
  onSignatureChanged: colorsFile.reload()

  function parse(raw) {
    var parsed = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (match) parsed[match[1]] = match[2]
    }
    return parsed
  }

  property FileView colorsFile: FileView {
    id: colorsFile
    path: Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: root.values = root.parse(text())
    onLoadFailed: root.values = {}
  }
}
