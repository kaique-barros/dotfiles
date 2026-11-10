import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

import "../models"

PopupModel {
  id: root

  property bool dockActive: false
  property bool edgeHovered: false

  // ================= CONFIGURAÇÕES =================
  popupWidth: showBoth ? (bar ? bar.osdWidthBoth : 110) : (bar ? bar.osdWidthSingle : 52)
  popupHeight: bar ? bar.osdHeight : 210
  padding: bar ? bar.osdPadding : 6

  property color osdIconColor: bar ? bar.osdIconColor : "#1e1e2e"
  property color osdTextColor: bar ? bar.osdTextColor : "#1e1e2e"
  property color osdFillColor: bar ? bar.osdFillColor : "#1e1e2e"
  property color osdKnobBorderColor: bar ? bar.osdKnobBorderColor : "white"
  property color osdTrackColor: bar ? bar.osdTrackColor : "#e4e4ea"
  property color osdKnobColor: bar ? bar.osdKnobColor : "#11111b"
  property color osdDividerColor: bar ? bar.osdDividerColor : "#9ca3af"
  property color osdMutedColor: bar ? bar.dangerColor : "#d32f2f"   // volume mudo
  property color osdKnobMutedColor: bar ? bar.osdKnobMutedColor : "#757575"
  property real osdFontSize: bar ? bar.osdFontSize : 10
  property string fontFamily: bar ? bar.fontFamily : ""
  readonly property string family: fontFamily !== "" ? fontFamily : Qt.application.font.family
  pos: Math.round((bar.height - popupHeight) / 2)

  // largura útil dentro do popup (não depende do conteúdo, evita loop de binding)
  readonly property real contentWidth: popupWidth - 2 * padding
  // =================================================

  // ================= VISIBILIDADE =================
  readonly property bool showBoth: edgeHovered || hovered || dockActive

  // O último controle alterado é o único exibido quando
  // o popup não está sendo aberto pelo mouse ou pela dock.
  property string activeOSD: ""

  readonly property bool showBrightness:
    showBoth || activeOSD === "brightness"

  readonly property bool showVolume:
    showBoth || activeOSD === "volume"

  open: showBoth || activeOSD !== ""

  function triggerOSD(control) {
    activeOSD = control
    osdTimer.restart()
  }

  Timer {
    id: osdTimer
    interval: 2500
    onTriggered: root.activeOSD = ""
  }

  // ================= VOLUME =================
  readonly property PwNode defaultSink: Pipewire.defaultAudioSink

  PwObjectTracker {
    objects: root.defaultSink ? [root.defaultSink] : []
  }

  readonly property real currentVol:
    (defaultSink && defaultSink.audio) ? defaultSink.audio.volume : 0

  readonly property bool isMuted:
    (defaultSink && defaultSink.audio) ? defaultSink.audio.muted : false

  property real lastRecordedVol: -1
  property bool lastRecordedMute: false
  property bool isInitialized: false

  onCurrentVolChanged: {
    if (!isInitialized) {
      lastRecordedVol = currentVol
      isInitialized = true
      return
    }

    if (Math.abs(currentVol - lastRecordedVol) > 0.005) {
      lastRecordedVol = currentVol
      triggerOSD("volume")
    }
  }

  onIsMutedChanged: {
    if (!isInitialized) {
      lastRecordedMute = isMuted
      return
    }

    if (isMuted !== lastRecordedMute) {
      lastRecordedMute = isMuted
      triggerOSD("volume")
    }
  }

  // ================= BRILHO =================
  property real currentBrightness: 0
  property bool brightnessInitialized: false

  property real pendingBrightness: -1     // próximo valor a enviar ao brightnessctl
  property real holdUntil: 0              // ignora leituras logo depois de você mexer
  property bool queryAgain: false         // chegou outro evento enquanto lia

  function readBrightness(line) {

    if (Date.now() < holdUntil || pendingBrightness >= 0)
      return

    const fields = line.trim().split(",")
    if (fields.length < 5)
      return

    const percentage = parseFloat(fields[3].replace("%", ""))
    if (isNaN(percentage))
      return

    const nextValue = Math.max(0, Math.min(1, percentage / 100))

    if (!brightnessInitialized) {
      currentBrightness = nextValue
      brightnessInitialized = true
      return
    }

    if (Math.abs(nextValue - currentBrightness) > 0.005) {
      currentBrightness = nextValue
      triggerOSD("brightness")
    }
  }

  // lê o brilho; se já estiver lendo, lê de novo ao terminar (não perde o valor final)
  function requestBrightnessRead() {
    if (brightnessQuery.running) queryAgain = true
    else brightnessQuery.running = true
  }

  function setBrightness(value) {
    const v = Math.max(0.01, Math.min(1, value))

    currentBrightness = v               // a barra e o número mudam na hora
    brightnessInitialized = true
    pendingBrightness = v
    holdUntil = Date.now() + 700
    triggerOSD("brightness")

    if (!brightnessSetter.running)
      flushBrightness()
  }

  function flushBrightness() {
    if (pendingBrightness < 0)
      return

    const percentage = Math.round(pendingBrightness * 100)
    pendingBrightness = -1

    brightnessSetter.command = ["brightnessctl", "-q", "set", percentage + "%"]
    brightnessSetter.running = true
  }

  Process {
    id: brightnessQuery
    command: ["brightnessctl", "-m"]

    stdout: SplitParser {
      onRead: line => root.readBrightness(line)
    }

    onExited: {
      if (root.queryAgain) {
        root.queryAgain = false
        running = true
      }
    }
  }

  Process {
    id: brightnessSetter

    onExited: {
      if (root.pendingBrightness >= 0)
        root.flushBrightness()          // chegou um valor novo enquanto rodava
    }
  }

  // escuta os eventos de backlight do kernel (sem timer)
  Process {
    id: brightnessWatcher
    command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
    running: true

    stdout: SplitParser {
      onRead: line => {
        if (line.indexOf("change") >= 0)
          root.requestBrightnessRead()
      }
    }
  }

  Component.onCompleted: requestBrightnessRead()

  // ================= CONTEÚDO =================
  Row {
    anchors.centerIn: parent
    height: parent.height
    spacing: root.showBoth ? 8 : 0

    // ---------- BRILHO ----------
    Item {
      visible: root.showBrightness
      width: root.showBoth ? 42 : root.contentWidth
      height: parent.height

      Column {
        anchors.centerIn: parent
        spacing: 10

        Item {
          width: 32
          height: 32
          anchors.horizontalCenter: parent.horizontalCenter

          Icon {
            anchors.centerIn: parent
            source: "file://" + Quickshell.shellPath("assets/brightness.svg")
            color: root.osdIconColor
            size: 20
          }
        }

        Item {
          id: brightnessSlider
          width: 12
          height: 120
          anchors.horizontalCenter: parent.horizontalCenter

          Rectangle {
            id: brightnessTrack
            anchors.fill: parent
            radius: width / 2
            color: root.osdTrackColor

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(
                0,
                Math.min(
                  brightnessTrack.height,
                  brightnessTrack.height * root.currentBrightness
                )
              )
              radius: width / 2
              color: root.osdFillColor
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              y: Math.max(
                0,
                Math.min(
                  brightnessTrack.height - height,
                  brightnessTrack.height * (1.0 - root.currentBrightness) - height / 2
                )
              )
              width: 16
              height: 16
              radius: 8
              color: root.osdKnobColor
              border.color: root.osdKnobBorderColor
              border.width: 2
            }
          }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor

            function applyY(mouseY) {
              const adjustedY = mouseY - 8
              const value = Math.max(
                0,
                Math.min(1, 1.0 - adjustedY / brightnessTrack.height)
              )

              root.setBrightness(value)
            }

            onPressed: mouse => applyY(mouse.y)

            onPositionChanged: mouse => {
              if (pressed)
                applyY(mouse.y)
            }

            onWheel: wheel => {
              const step = wheel.angleDelta.y > 0 ? 0.02 : -0.02
              root.setBrightness(root.currentBrightness + step)
            }
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Math.round(root.currentBrightness * 100) + "%"
          font.family: root.family
          font.pixelSize: root.osdFontSize
          font.bold: true
          color: root.osdTextColor
        }
      }
    }

    // ---------- SEPARADOR ----------
    Rectangle {
      visible: root.showBoth
      width: 1
      height: 160
      anchors.verticalCenter: parent.verticalCenter
      color: root.osdDividerColor
    }

    // ---------- VOLUME ----------
    Item {
      visible: root.showVolume
      width: root.showBoth ? 42 : root.contentWidth
      height: parent.height

      Column {
        anchors.centerIn: parent
        spacing: 10

        Item {
          width: 32
          height: 32
          anchors.horizontalCenter: parent.horizontalCenter

          readonly property string iconAsset: {
            if (root.isMuted) return "assets/volume_muted.svg"
            if (root.currentVol <= 0.001) return "assets/volume_zero.svg"
            if (root.currentVol < 0.50) return "assets/volume_low.svg"
            return "assets/volume_high.svg"
          }

          Icon {
            anchors.centerIn: parent
            size: 20
            color: root.isMuted ? root.osdMutedColor : root.osdIconColor
            source: "file://" + Quickshell.shellPath(parent.iconAsset)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: {
              if (root.defaultSink && root.defaultSink.audio)
                root.defaultSink.audio.muted = !root.defaultSink.audio.muted
            }
          }
        }

        Item {
          id: volumeSlider
          width: 12
          height: 120
          anchors.horizontalCenter: parent.horizontalCenter

          Rectangle {
            id: volumeTrack
            anchors.fill: parent
            radius: width / 2
            color: root.osdTrackColor

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(
                0,
                Math.min(volumeTrack.height, volumeTrack.height * root.currentVol)
              )
              radius: width / 2
              color: root.isMuted ? root.osdDividerColor : root.osdFillColor
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              y: Math.max(
                0,
                Math.min(
                  volumeTrack.height - height,
                  volumeTrack.height * (1.0 - root.currentVol) - height / 2
                )
              )
              width: 16
              height: 16
              radius: 8
              color: root.isMuted ? root.osdKnobMutedColor : root.osdKnobColor
              border.color: root.osdKnobBorderColor
              border.width: 2
            }
          }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor

            function applyY(mouseY) {
              if (root.defaultSink && root.defaultSink.audio) {
                const adjustedY = mouseY - 8
                const value = Math.max(
                  0,
                  Math.min(1, 1.0 - adjustedY / volumeTrack.height)
                )

                root.defaultSink.audio.volume = value
              }
            }

            onPressed: mouse => applyY(mouse.y)

            onPositionChanged: mouse => {
              if (pressed)
                applyY(mouse.y)
            }

            onWheel: wheel => {
              if (root.defaultSink && root.defaultSink.audio) {
                const step = 0.02 * (wheel.angleDelta.y > 0 ? 1 : -1)

                root.defaultSink.audio.volume = Math.max(
                  0,
                  Math.min(1, root.defaultSink.audio.volume + step)
                )
              }
            }
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.isMuted
            ? "Mudo"
            : Math.round(root.currentVol * 100) + "%"
          font.family: root.family
          font.pixelSize: root.osdFontSize
          font.bold: true
          color: root.isMuted ? root.osdMutedColor : root.osdTextColor
        }
      }
    }
  }

  WheelHandler {
    onWheel: wheel => {
      if (root.defaultSink && root.defaultSink.audio) {
        const step = 0.02 * (wheel.angleDelta.y > 0 ? 1 : -1)

        root.defaultSink.audio.volume = Math.max(
          0,
          Math.min(1, root.defaultSink.audio.volume + step)
        )
      }
    }
  }
}
