import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

import "../../theme"
import "../models"

// Controle de volume conectado à borda direita, como um popup da moldura.
// Aparece por hover na borda, ao mudar o volume ou com a dock aberta.
PopupModel {
  id: root

  property bool dockActive: false

  // ================= CONFIGURAÇÕES =================
  popupWidth: 52
  popupHeight: 210
  padding: 6
  pos: Math.round((bar.height - popupHeight) / 2)    // centralizado na vertical
  // =================================================

  readonly property PwNode defaultSink: Pipewire.defaultAudioSink

  PwObjectTracker {
    objects: root.defaultSink ? [root.defaultSink] : []
  }

  readonly property real currentVol: (defaultSink && defaultSink.audio) ? defaultSink.audio.volume : 0
  readonly property bool isMuted: (defaultSink && defaultSink.audio) ? defaultSink.audio.muted : false

  // ================= TRIGGERS DE VISIBILIDADE =================
  property bool edgeHovered: false          // ligado pelo detector da borda (Bar.qml)
  property bool volumeChangedActive: false

  // `hovered` vem do PopupModel (mouse sobre o popup)
  readonly property bool isVisible: edgeHovered || hovered || volumeChangedActive || dockActive
  open: isVisible

  // Detecção de mudança de volume para exibir o OSD temporariamente
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
      triggerVolumeOSD()
    }
  }

  onIsMutedChanged: {
    if (!isInitialized) {
      lastRecordedMute = isMuted
      return
    }
    if (isMuted !== lastRecordedMute) {
      lastRecordedMute = isMuted
      triggerVolumeOSD()
    }
  }

  function triggerVolumeOSD() {
    volumeChangedActive = true
    osdTimer.restart()
  }

  Timer {
    id: osdTimer
    interval: 2500
    onTriggered: root.volumeChangedActive = false
  }

  // ================= CONTEÚDO =================
  Column {
    anchors.centerIn: parent
    spacing: 10

    // Ícone acima da barra
    Item {
      width: 32
      height: 32
      anchors.horizontalCenter: parent.horizontalCenter

      readonly property string iconAsset: {
        if (root.isMuted) return "volume_muted.svg"
        if (root.currentVol <= 0.001) return "volume_zero.svg"
        if (root.currentVol < 0.50) return "volume_low.svg"
        return "volume_high.svg"
      }

      Icon {
        anchors.centerIn: parent
        size: 20
        color: root.isMuted ? "#d32f2f" : "#1e1e2e"
        source: Theme.asset(parent.iconAsset)
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.defaultSink && root.defaultSink.audio) {
            root.defaultSink.audio.muted = !root.defaultSink.audio.muted
          }
        }
      }
    }

    // Slider Vertical de Volume
    Item {
      id: vSlider
      width: 12
      height: 120
      anchors.horizontalCenter: parent.horizontalCenter

      Rectangle {
        id: track
        anchors.fill: parent
        radius: width / 2
        color: "#e4e4ea"

        // Preenchimento de baixo para cima
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: Math.max(0, Math.min(track.height, track.height * root.currentVol))
          radius: width / 2
          color: root.isMuted ? "#9ca3af" : "#1e1e2e"
        }

        // Knob / Handle do Slider
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          y: Math.max(0, Math.min(track.height - height, track.height * (1.0 - root.currentVol) - height / 2))
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
        anchors.margins: -8 // Facilita clicar e arrastar
        cursorShape: Qt.PointingHandCursor

        function applyY(mouseY) {
          if (root.defaultSink && root.defaultSink.audio) {
            const adjustedY = mouseY - 8
            const clamped = Math.max(0, Math.min(1.0, 1.0 - (adjustedY / track.height)))
            root.defaultSink.audio.volume = clamped
          }
        }

        onPressed: (mouse) => applyY(mouse.y)
        onPositionChanged: (mouse) => {
          if (pressed) applyY(mouse.y)
        }
        onWheel: (wheel) => {
          if (root.defaultSink && root.defaultSink.audio) {
            const step = 0.02 * (wheel.angleDelta.y > 0 ? 1 : -1)
            root.defaultSink.audio.volume = Math.max(0, Math.min(1.0, root.defaultSink.audio.volume + step))
          }
        }
      }
    }

    // Porcentagem abaixo da barra
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.isMuted ? "Mudo" : (Math.round(root.currentVol * 100) + "%")
      font.pixelSize: 10
      font.bold: true
      color: root.isMuted ? "#d32f2f" : "#1e1e2e"
    }
  }

  WheelHandler {
    onWheel: (wheel) => {
      if (root.defaultSink && root.defaultSink.audio) {
        const step = 0.02 * (wheel.angleDelta.y > 0 ? 1 : -1)
        root.defaultSink.audio.volume = Math.max(0, Math.min(1.0, root.defaultSink.audio.volume + step))
      }
    }
  }
}
