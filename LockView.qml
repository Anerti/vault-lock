import QtQuick
import QtQuick.Effects
import qs.Commons

// The Omarchy terminal lock screen, laid out like a RobCo terminal: OMARCHY (TM)
// TERMINAL PROTOCOL over the Omarchy mark in Vault-Tec wings, then a centred
// banner (the Omarchy and kernel versions, the copyright and the hostname), all
// typing itself out, a rule, then a left-aligned "> ENTER PASSWORD:" prompt echoing an
// asterisk per character. A status line under the prompt reports the check
// (ACCESS DENIED in red, the words being the cue that does not rely on colour),
// and the PLEASE STAND BY card shows once the password checks out.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  // Set by the service between a successful check and the unlock.
  property bool granting: false
  property string omarchyVersion: ""
  property string kernelVersion: ""
  property string hostName: ""

  readonly property color fg: Color.foreground
  readonly property color muted: Color.muted
  readonly property color urgent: Color.urgent
  readonly property color bright: themePalette.brightForeground
  readonly property color bg: Color.background
  readonly property color bgDeep: themePalette.darkBackground
  readonly property color bgGlow: themePalette.lighterBackground
  readonly property string textFamily: shareTech.status === FontLoader.Ready ? shareTech.name : Style.font.family

  ThemePalette { id: themePalette }

  readonly property bool errorState: failureMessage.length > 0
  readonly property bool cursorOn: inputEnabled && !authenticatingPassword && !granting
  readonly property real rem: px(16)
  readonly property int termSize: Math.round(rem * 1.25)
  readonly property int promptSize: Math.round(rem * 1.6)
  readonly property real termTracking: 0.1

  readonly property var bannerLines: {
    var lines = ["OMARCHY (TM) TERMINAL PROTOCOL"]
    var versions = []
    if (omarchyVersion.length > 0) versions.push("OMARCHY VERSION " + omarchyVersion)
    if (kernelVersion.length > 0) versions.push("KERNEL VERSION " + kernelVersion)
    if (versions.length > 0) lines.push(versions.join(" | "))
    lines.push("COPYRIGHT 2025 - " + new Date().getFullYear() + " OMARCHY")
    if (hostName.length > 0) lines.push("- " + hostName + " -")
    return lines.map(function(line) { return line.toUpperCase() })
  }
  readonly property string promptLabel: "> ENTER PASSWORD: "

  readonly property int typeInterval: 35
  readonly property int linePause: 6
  readonly property int logoTicks: 22
  readonly property int ruleTicks: 10
  readonly property int logoStart: bannerLines[0].length + linePause
  readonly property var bannerStarts: {
    var starts = []
    var tick = 0
    for (var i = 0; i < bannerLines.length; i++) {
      starts.push(tick)
      tick += bannerLines[i].length + linePause
      if (i === 0) tick += logoTicks + linePause
    }
    starts.push(tick)
    return starts
  }
  readonly property int ruleStart: bannerStarts[bannerLines.length]
  readonly property int promptStart: ruleStart + ruleTicks + linePause
  readonly property int typingEnd: promptStart + promptLabel.length
  readonly property bool promptReady: typed >= typingEnd
  property int typed: 0
  property bool typing: false

  function px(n) { return Style.space(n) }
  function glowOf(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function cssOf(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")" }

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function restartTyping() {
    typed = 0
    typing = true
    typingDelay.restart()
  }

  function finishTyping() {
    typingDelay.stop()
    typer.stop()
    typed = typingEnd
    typing = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onLoadBackgroundChanged: if (loadBackground) restartTyping()
  onTypingEndChanged: if (!typing && typed > 0) typed = typingEnd
  Component.onCompleted: {
    syncPasswordText()
    restartTyping()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  FontLoader {
    id: shareTech
    source: Qt.resolvedUrl("assets/fonts/ShareTechMono-Regular.ttf")
  }

  Timer {
    id: typingDelay
    interval: 400
    onTriggered: typer.start()
  }

  Timer {
    id: typer
    interval: root.typeInterval
    repeat: true
    onTriggered: {
      if (root.typed >= root.typingEnd) {
        stop()
        root.typing = false
      } else {
        root.typed += 1
      }
    }
  }

  Timer {
    id: blink
    property bool on: true
    interval: 500
    repeat: true
    running: root.loadBackground && !root.granting
    onRunningChanged: on = true
    onTriggered: on = !on
  }

  // .lock background: a faint green bloom above centre over a deep radial.
  Canvas {
    id: backdrop
    anchors.fill: parent
    readonly property var shades: [root.fg, root.bg, root.bgDeep, root.bgGlow]
    onShadesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function ellipse(ctx, cx, cy, rx, ry, stops) {
      ctx.save()
      ctx.translate(cx, cy)
      ctx.scale(rx, ry)
      var g = ctx.createRadialGradient(0, 0, 0, 0, 0, 1)
      for (var i = 0; i < stops.length; i++) g.addColorStop(stops[i][0], stops[i][1])
      ctx.fillStyle = g
      ctx.fillRect(-cx / rx, -cy / ry, width / rx, height / ry)
      ctx.restore()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.fillStyle = root.bgDeep
      ctx.fillRect(0, 0, width, height)
      ellipse(ctx, width / 2, height / 2, width * 1.3, height * 1.1,
        [[0, root.cssOf(root.bgGlow, 1)], [0.5, root.cssOf(root.bg, 1)], [1, root.cssOf(root.bgDeep, 1)]])
      ellipse(ctx, width / 2, height * 0.44, width * 0.6, height * 0.55,
        [[0, root.cssOf(root.fg, 0.10)], [0.62, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0)"]])
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
    onPositionChanged: root.wakeRequested()
  }

  component TermText: Text {
    id: termText
    property real tracking: root.termTracking
    property int size: root.termSize
    color: root.fg
    font.family: root.textFamily
    font.pixelSize: size
    font.letterSpacing: size * tracking
    // Qt spaces after the last glyph too; pad the front the same so it centres.
    leftPadding: size * tracking
    layer.enabled: visible
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: root.glowOf(termText.color, 0.45)
      shadowBlur: 0.4
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      autoPaddingEnabled: true
    }
  }

  component TypedLine: Item {
    id: typedLine
    property string text
    property int shown: text.length
    property bool cursor: false
    property color color: root.fg
    property int size: root.termSize

    implicitWidth: full.implicitWidth
    implicitHeight: full.implicitHeight

    TermText { id: full; visible: false; text: typedLine.text; size: typedLine.size }

    TermText {
      id: part
      text: typedLine.text.substring(0, Math.max(0, typedLine.shown))
      color: typedLine.color
      size: typedLine.size
    }

    Rectangle {
      x: part.implicitWidth
      anchors.verticalCenter: parent.verticalCenter
      width: Math.round(typedLine.size * 0.62)
      height: typedLine.size
      color: typedLine.color
      visible: typedLine.cursor && blink.on
    }
  }

  Column {
    id: terminal
    anchors.top: parent.top
    anchors.topMargin: Math.max(root.px(40), root.height * 0.07)
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(root.width - root.px(128), root.px(1100))
    spacing: root.px(28)

    TypedLine {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.bannerLines[0]
      shown: root.typed - root.bannerStarts[0]
      cursor: root.typed < root.logoStart
    }

    Item {
      id: emblemSlot
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(terminal.width * 0.7, root.px(520))
      height: logoHeight + 2 * margin

      readonly property real logoHeight: width * 360 / 930.07
      readonly property real margin: root.px(14)
      readonly property real glowPad: haze.blurMax
      readonly property real reveal: Math.max(0, Math.min(1, (root.typed - root.logoStart) / root.logoTicks))

      Item {
        x: -emblemSlot.glowPad
        y: emblemSlot.margin - emblemSlot.glowPad
        width: emblemSlot.width + 2 * emblemSlot.glowPad
        height: emblemSlot.reveal <= 0 ? 0
          : emblemSlot.reveal >= 1 ? emblemSlot.logoHeight + 2 * emblemSlot.glowPad
          : emblemSlot.glowPad + emblemSlot.logoHeight * emblemSlot.reveal
        clip: emblemSlot.reveal < 1

        Item {
          id: emblem
          x: emblemSlot.glowPad
          y: emblemSlot.glowPad
          width: emblemSlot.width
          height: emblemSlot.logoHeight
          opacity: 0.92
          transformOrigin: Item.Center

          Image {
            id: emblemImage
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/vaulttec-omarchy.svg")
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: false
          }

          // The mockup's three stacked drop-shadows: wide haze, then a tight glow.
          MultiEffect {
            id: haze
            anchors.fill: emblemImage
            source: emblemImage
            colorization: 1.0
            colorizationColor: root.fg
            shadowEnabled: true
            shadowColor: root.glowOf(root.fg, 0.4)
            shadowBlur: 1.0
            blurMax: 64
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            autoPaddingEnabled: true
          }

          MultiEffect {
            anchors.fill: emblemImage
            source: emblemImage
            colorization: 1.0
            colorizationColor: root.fg
            shadowEnabled: true
            shadowColor: root.glowOf(root.fg, 0.6)
            shadowBlur: 0.35
            blurMax: 16
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            autoPaddingEnabled: true
          }

          // @keyframes holo
          SequentialAnimation {
            running: root.loadBackground && root.visible && !root.granting
            loops: Animation.Infinite
            ParallelAnimation {
              NumberAnimation { target: emblem; property: "opacity"; to: 1; duration: 2250; easing.type: Easing.InOutSine }
              NumberAnimation { target: emblem; property: "scale"; to: 1.012; duration: 2250; easing.type: Easing.InOutSine }
            }
            ParallelAnimation {
              NumberAnimation { target: emblem; property: "opacity"; to: 0.92; duration: 2250; easing.type: Easing.InOutSine }
              NumberAnimation { target: emblem; property: "scale"; to: 1; duration: 2250; easing.type: Easing.InOutSine }
            }
          }
        }
      }

      Rectangle {
        y: emblemSlot.margin + emblemSlot.logoHeight * emblemSlot.reveal
        width: emblemSlot.width
        height: root.px(2)
        color: root.fg
        visible: emblemSlot.reveal > 0 && emblemSlot.reveal < 1
        layer.enabled: visible
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: root.glowOf(root.fg, 0.8)
          shadowBlur: 0.5
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          autoPaddingEnabled: true
        }
      }
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: root.px(4)

      Repeater {
        model: root.bannerLines.slice(1)

        TypedLine {
          required property string modelData
          required property int index
          anchors.horizontalCenter: parent.horizontalCenter
          text: modelData
          shown: root.typed - root.bannerStarts[index + 1]
          cursor: root.typed >= root.bannerStarts[index + 1] && root.typed < root.bannerStarts[index + 2]
        }
      }
    }

    Item {
      width: terminal.width
      height: root.px(2)

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * Math.max(0, Math.min(1, (root.typed - root.ruleStart) / root.ruleTicks))
        height: parent.height
        color: root.fg
        layer.enabled: width > 0
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: root.glowOf(root.fg, 0.6)
          shadowBlur: 0.4
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          autoPaddingEnabled: true
        }
      }
    }

    Column {
      width: terminal.width
      spacing: root.px(14)

      Item {
        id: promptRow
        width: parent.width
        height: promptLine.implicitHeight

        TypedLine {
          id: promptLine
          text: root.promptLabel
          size: root.promptSize
          shown: root.typed - root.promptStart
          cursor: root.typed >= root.promptStart && !root.promptReady
        }

        Item {
          id: starsBox
          anchors.left: promptLine.right
          anchors.right: parent.right
          height: parent.height
          clip: true
          visible: root.promptReady

          Row {
            id: stars
            x: width > starsBox.width ? starsBox.width - width : 0

            TermText {
              text: "*".repeat(passwordInput.text.length)
              size: root.promptSize
              leftPadding: 0
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.round(root.promptSize * 0.62)
              height: root.promptSize
              color: root.fg
              opacity: root.cursorOn && passwordInput.activeFocus && blink.on ? 1 : 0
            }
          }
        }

        TextInput {
          id: passwordInput
          anchors.fill: parent
          // Typed blind: the asterisks are the only echo.
          opacity: 0
          activeFocusOnPress: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          echoMode: TextInput.Password
          passwordMaskDelay: 0
          cursorVisible: false
          selectByMouse: false

          onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0) {
              root.wakeRequested()
              root.finishTyping()
            }
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            root.finishTyping()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }
      }

      TypedLine {
        id: statusLine
        readonly property string message: root.authenticatingPassword ? "> VERIFYING..."
          : root.errorState ? "> ACCESS DENIED"
          : root.fingerprintConfigured ? "> OR PLACE A FINGER ON THE SCANNER" : ""
        text: message
        color: root.errorState ? root.urgent : (root.authenticatingPassword ? root.fg : root.muted)
        visible: root.promptReady
        shown: 0
        onMessageChanged: Qt.callLater(retype)
        onVisibleChanged: Qt.callLater(retype)

        function retype() {
          statusTyper.stop()
          shown = 0
          if (visible) statusTyper.start()
        }

        NumberAnimation {
          id: statusTyper
          target: statusLine
          property: "shown"
          from: 0
          to: statusLine.message.length
          duration: statusLine.message.length * root.typeInterval
        }
      }
    }
  }

  // .granted: the PLEASE STAND BY test card with its own heavier CRT, faded in
  // over everything while the service holds the lock for the hand-off.
  Rectangle {
    id: granted
    anchors.fill: parent
    color: root.bgDeep
    opacity: root.granting ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

    MouseArea { anchors.fill: parent }

    Image {
      id: card
      anchors.fill: parent
      source: root.loadBackground && (root.authenticatingPassword || root.granting || granted.visible)
        ? Qt.resolvedUrl("assets/please-stand-by.jpg") : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: width
      sourceSize.height: height
      visible: false
    }

    MultiEffect {
      anchors.fill: card
      source: card
      colorization: 1.0
      colorizationColor: root.fg
    }

    // Edge vignette (not a flat darkening, which buries the card's black text)
    // and the faint green bloom.
    Canvas {
      anchors.fill: parent
      readonly property var shades: [root.fg, root.bgDeep]
      onShadesChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        backdrop.ellipse(ctx, width / 2, height / 2, width * 1.2, height * 1.0,
          [[0, root.cssOf(root.bgDeep, 0.08)], [0.28, root.cssOf(root.bgDeep, 0.08)], [0.7, root.cssOf(root.bgDeep, 0.42)], [1, root.cssOf(root.bgDeep, 0.86)]])
        backdrop.ellipse(ctx, width / 2, height * 0.44, width * 0.6, height * 0.55,
          [[0, root.cssOf(root.fg, 0.10)], [0.62, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0)"]])
      }
    }

    // Scanlines: 2px clear, 2px at 0.32.
    Canvas {
      anchors.fill: parent
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = "rgba(0,0,0,0.32)"
        for (var y = 2; y < height; y += 4) ctx.fillRect(0, y, width, 2)
      }
    }

    // Rolling beam.
    Rectangle {
      id: beam
      width: parent.width
      height: parent.height * 0.2
      gradient: Gradient {
        GradientStop { position: 0.0; color: Util.alpha(root.bright, 0) }
        GradientStop { position: 0.5; color: Util.alpha(root.bright, 0.10) }
        GradientStop { position: 1.0; color: Util.alpha(root.bright, 0) }
      }

      NumberAnimation on y {
        from: -beam.height
        to: granted.height
        duration: 2800
        loops: Animation.Infinite
        running: granted.visible
      }
    }
  }
}
