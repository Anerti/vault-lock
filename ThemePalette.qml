import QtQuick
import Quickshell.Io
import qs.Commons as Commons

QtObject {
  id: root

  property var values: ({})

  readonly property color brightForeground: values.bright_foreground || Commons.Color.foreground
  readonly property color darkBackground: values.dark_background || Commons.Color.background
  readonly property color darkerBackground: values.darker_background || darkBackground

  readonly property string signature: [Commons.Color.currentThemePath, Commons.Color.foreground, Commons.Color.background, Commons.Color.accent, Commons.Color.muted, Commons.Color.urgent].join()
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
    path: Commons.Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.values = root.parse(text())
    onLoadFailed: root.values = {}
    onFileChanged: reload()
  }
}
