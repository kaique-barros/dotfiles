import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

import "../../theme"
import "../models"

// Widget de mídia: capa, título, artista, tempo, barra de progresso e botões.
// Usa o primeiro player que estiver tocando (ou o primeiro da lista).
Box {
  id: root

  // ================= CONFIGURAÇÕES =================
  property string layoutMode: "auto"         // "auto" | "vertical" | "horizontal"
  property real contentSpacing: 10           // espaço entre as partes

  // textos
  property color textColor: "white"
  property color subTextColor: "#dddddd"
  property real titleSize: 15
  property real artistSize: 12
  property bool showAlbum: false

  // capa
  property real coverMaxSize: 160            // tamanho máximo da capa (diminua para uma capa menor)
  property real coverRadius: 12
  property real coverQuality: 2              // resolução carregada = tamanho * este valor (mais nítido)
  property string idleIcon: "media_idle.svg" // aparece no lugar da capa
  property color idleIconColor: "#666666"
  property real idleIconRatio: 0.45
  property bool cdShape: true                // capa redonda, como um CD
  property bool spin: true                   // gira enquanto toca
  property int spinDuration: 8000            // ms por volta (maior = mais devagar)
  property real holeRatio: 0.16              // furo do meio, em relação à capa
  property real hubRatio: 0.32               // anel claro em volta do furo
  property color hubColor: "#55ffffff"
  readonly property bool spinning:
    cdShape && spin && !!player && player.playbackState === MprisPlaybackState.Playing

  // progresso
  property bool showProgress: true
  property real timeSize: 11
  property color progressTrackColor: "#33000000"
  property color progressFillColor: "black"

  // botões
  property real buttonSize: 38
  property real iconSize: 20
  property real buttonSpacing: 14
  property color controlColor: "black"
  property color playBackground: "black"
  property color playIconColor: "white"

  // ícones (arquivos em assets/)
  property string previousIcon: "media_previous.svg"
  property string playIcon: "media_play.svg"
  property string pauseIcon: "media_pause.svg"
  property string nextIcon: "media_next.svg"

  // reserva para players sem capa (ex.: YouTube no navegador)
  property bool useYoutubeThumb: true
  property string youtubeThumb: "maxresdefault"   // maxresdefault (1280x720) | mqdefault (320x180)
  // =================================================

  readonly property bool vertical:
      layoutMode === "vertical"
      || (layoutMode === "auto" && content.height >= content.width * 0.8)

  readonly property var player: {
    const all = Mpris.players.values
    let first = null
    for (let i = 0; i < all.length; i++) {
      if (all[i].isPlaying) return all[i]
      if (!first) first = all[i]
    }
    return first
  }

  function asset(name) { return Theme.asset(name) }

  function fmt(sec) {
    const s = Math.max(0, Math.floor(sec || 0))
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const r = s % 60
    const rr = (r < 10 ? "0" : "") + r
    if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + rr
    return m + ":" + rr
  }

  // ---------- capa: recarrega quando a música muda ----------
  property string artSource: ""

  function youtubeId(url) {
    const s = String(url || "")
    const m = s.match(/[?&]v=([\w-]{6,})/) || s.match(/youtu\.be\/([\w-]{6,})/)
    return m ? m[1] : ""
  }

  function currentArtUrl() {
    if (!player) return ""

    const art = player.trackArtUrl ? player.trackArtUrl.toString() : ""
    if (art !== "") return art

    if (!useYoutubeThumb) return ""
    const meta = player.metadata || {}
    const id = youtubeId(meta["xesam:url"])
    return id !== "" ? "https://i.ytimg.com/vi/" + id + "/" + youtubeThumb + ".jpg" : ""
  }

  function refreshArt() {
    const u = currentArtUrl()
    if (u === artSource) {
      artSource = ""
      Qt.callLater(() => { root.artSource = root.currentArtUrl() })
    } else {
      artSource = u
    }
  }

  onArtSourceChanged: console.log("ART url:", artSource)

  onPlayerChanged: refreshArt()
  Component.onCompleted: refreshArt()

  Connections {
    target: root.player
    ignoreUnknownSignals: true
    function onTrackTitleChanged() { root.refreshArt() }
    function onTrackArtUrlChanged() { root.refreshArt() }
    function onMetadataChanged() { root.refreshArt() }
  }

  // a posição não se atualiza sozinha: só enquanto estiver tocando e visível
  Timer {
    interval: 1000
    repeat: true
    running: root.showProgress && root.visible && !!root.player && root.player.isPlaying
    onTriggered: root.player.positionChanged()
  }

  // ---------- layout ----------
  Item {
    id: content
    anchors.fill: parent

    readonly property real gap: root.contentSpacing
    readonly property real progressH: root.showProgress ? 30 : 0
    readonly property real controlsH: root.buttonSize

    readonly property real coverSize: Math.max(0, root.vertical
      ? Math.min(width, root.coverMaxSize, height - infoCol.implicitHeight - progressH - controlsH - 3 * gap)
      : Math.min(height, root.coverMaxSize))

    // área dos textos/botões: embaixo da capa (vertical) ou ao lado dela (horizontal)
    readonly property real rightX: root.vertical ? 0 : coverSize + gap
    readonly property real rightW: Math.max(0, width - rightX)

    // capa
    Item {
      id: cover
      x: root.vertical ? (content.width - width) / 2 : 0
      y: 0
      width: content.coverSize
      height: width

      // o disco: é ele que gira
      Item {
        id: disc
        anchors.fill: parent

        NumberAnimation on rotation {
          from: 0
          to: 360
          duration: root.spinDuration
          loops: Animation.Infinite
          running: true
          paused: !root.spinning
        }

        ClippingRectangle {
          anchors.fill: parent
          radius: root.cdShape ? width / 2 : root.coverRadius
          color: "#b8b8b8"
          antialiasing: true

          Image {
            id: art
            anchors.fill: parent
            source: root.artSource
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: true
            smooth: true
            mipmap: true
            sourceSize: Qt.size(cover.width * root.coverQuality, cover.height * root.coverQuality)
            visible: status === Image.Ready

            onStatusChanged: {
              if (status === Image.Error && root.artSource.indexOf("maxresdefault") >= 0)
                root.artSource = root.artSource.replace("maxresdefault", "mqdefault")
            }
          }
        }

        // anel claro em volta do furo
        Rectangle {
          visible: root.cdShape && art.visible
          anchors.centerIn: parent
          width: parent.width * root.hubRatio
          height: width
          radius: width / 2
          color: root.hubColor
        }

        // furo (da cor do fundo da caixa)
        Rectangle {
          visible: root.cdShape && art.visible
          anchors.centerIn: parent
          width: parent.width * root.holeRatio
          height: width
          radius: width / 2
          color: root.color
        }
      }

      // ícone de "nada tocando": fica fora do disco, então não gira
      Icon {
        anchors.centerIn: parent
        visible: !art.visible
        size: cover.height * root.idleIconRatio
        color: root.idleIconColor
        source: root.asset(root.idleIcon)
      }
    }

    // título / artista
    Column {
      id: infoCol
      x: content.rightX
      y: root.vertical ? content.coverSize + content.gap : 0
      width: content.rightW
      spacing: 2

      Text {
        width: parent.width
        horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
        text: root.player ? (root.player.trackTitle || "Sem título") : "Nada tocando"
        font.pixelSize: root.titleSize
        font.bold: true
        color: root.textColor
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
        text: root.player ? (root.player.trackArtist || "") : ""
        font.pixelSize: root.artistSize
        color: root.subTextColor
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        visible: root.showAlbum
        horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
        text: root.player ? (root.player.trackAlbum || "") : ""
        font.pixelSize: root.artistSize - 1
        color: root.subTextColor
        elide: Text.ElideRight
      }
    }

    // tempo + barra de progresso
    Item {
      id: progressBlock
      visible: root.showProgress && (!root.player || root.player.lengthSupported)
      x: content.rightX
      y: content.height - content.controlsH - content.gap - content.progressH
      width: content.rightW
      height: content.progressH

      Item {
        id: timeRow
        width: parent.width
        height: 14

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.player ? root.fmt(root.player.position) : "0:00"
          font.pixelSize: root.timeSize
          font.bold: true
          color: root.subTextColor
        }
        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: (root.player && root.player.lengthSupported) ? root.fmt(root.player.length) : "0:00"
          font.pixelSize: root.timeSize
          font.bold: true
          color: root.subTextColor
        }
      }

      Item {
        anchors.top: timeRow.bottom
        anchors.topMargin: 4
        width: parent.width
        height: 12

        Rectangle {
          id: track
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 4
          radius: 2
          color: root.progressTrackColor

          Rectangle {
            height: parent.height
            radius: 2
            color: root.progressFillColor
            width: (root.player && root.player.length > 0)
              ? parent.width * Math.max(0, Math.min(1, root.player.position / root.player.length))
              : 0
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: !!root.player && root.player.canSeek
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: (mouse) => {
            root.player.position = Math.max(0, Math.min(1, mouse.x / track.width)) * root.player.length
          }
        }
      }
    }

    // botões
    Item {
      id: controls
      x: content.rightX
      y: content.height - content.controlsH
      width: content.rightW
      height: content.controlsH

      Row {
        anchors.centerIn: parent
        spacing: root.buttonSpacing

        // anterior
        Rectangle {
          width: root.buttonSize; height: width; radius: width / 2
          color: prevArea.containsMouse ? "#22000000" : "transparent"
          opacity: (root.player && root.player.canGoPrevious) ? 1 : 0.35

          Icon {
            anchors.centerIn: parent
            size: root.iconSize
            color: root.controlColor
            source: root.asset(root.previousIcon)
          }
          MouseArea {
            id: prevArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !!root.player && root.player.canGoPrevious
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.previous()
          }
        }

        // tocar / pausar
        Rectangle {
          width: root.buttonSize; height: width; radius: width / 2
          color: root.playBackground
          opacity: (root.player && root.player.canTogglePlaying) ? 1 : 0.35

          Icon {
            anchors.centerIn: parent
            size: root.iconSize
            color: root.playIconColor
            source: root.asset(root.player && root.player.isPlaying ? root.pauseIcon : root.playIcon)
          }
          MouseArea {
            anchors.fill: parent
            enabled: !!root.player && root.player.canTogglePlaying
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.togglePlaying()
          }
        }

        // próxima
        Rectangle {
          width: root.buttonSize; height: width; radius: width / 2
          color: nextArea.containsMouse ? "#22000000" : "transparent"
          opacity: (root.player && root.player.canGoNext) ? 1 : 0.35

          Icon {
            anchors.centerIn: parent
            size: root.iconSize
            color: root.controlColor
            source: root.asset(root.nextIcon)
          }
          MouseArea {
            id: nextArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !!root.player && root.player.canGoNext
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.next()
          }
        }
      }
    }
  }
}
