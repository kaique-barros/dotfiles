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
  popupWidth: showBoth ? 110 : 52
  popupHeight: 210
  padding: 6
  pos: Math.round((bar.height - popupHeight) / 2)
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

  function readBrightness(line) {
    const fields = line.trim().split(",")

    if (fields.length < 5)
      return

    const percentage = parseFloat(fields[4].replace("%", ""))

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

  function setBrightness(value) {
    const percentage = Math.max(1, Math.min(100, Math.round(value * 100)))

    brightnessSetter.running = false
    brightnessSetter.command = [
      "brightnessctl",
      "-q",
      "set",
      percentage + "%"
    ]
    brightnessSetter.running = true

    triggerOSD("brightness")
  }

  Process {
    id: brightnessQuery

    command: ["brightnessctl", "-m"]

    stdout: SplitParser {
      onRead: line => root.readBrightness(line)
    }
  }

  Process {
    id: brightnessSetter

    onExited: {
      if (!brightnessQuery.running)
        brightnessQuery.running = true
    }
  }

  Component.onCompleted: brightnessQuery.running = true

  Timer {
    interval: 1000
    running: true
    repeat: true

    onTriggered: {
      if (!brightnessQuery.running)
        brightnessQuery.running = true
    }
  }

  // ================= CONTEÚDO =================
  Row {
    anchors.centerIn: parent
    height: parent.height
    spacing: root.showBoth ? 8 : 0

    // ---------- BRILHO ----------
    Item {
      visible: root.showBrightness
      width: root.showBoth ? 42 : parent.width
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
            color: "#1e1e2e"
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
            color: "#e4e4ea"

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
              color: "#1e1e2e"
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
              color: "#11111b"
              border.color: "white"
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
          font.pixelSize: 10
          font.bold: true
          color: "#1e1e2e"
        }
      }
    }

    // ---------- SEPARADOR ----------
    Rectangle {
      visible: root.showBoth
      width: 1
      height: 160
      anchors.verticalCenter: parent.verticalCenter
      color: "#9ca3af"
    }

    // ---------- VOLUME ----------
    Item {
      visible: root.showVolume
      width: root.showBoth ? 42 : parent.width
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
            color: root.isMuted ? "#d32f2f" : "#1e1e2e"
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
            color: "#e4e4ea"

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(
                0,
                Math.min(volumeTrack.height, volumeTrack.height * root.currentVol)
              )
              radius: width / 2
              color: root.isMuted ? "#9ca3af" : "#1e1e2e"
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
              color: root.isMuted ? "#757575" : "#11111b"
              border.color: "white"
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
          font.pixelSize: 10
          font.bold: true
          color: root.isMuted ? "#d32f2f" : "#1e1e2e"
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
