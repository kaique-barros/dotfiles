import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import "../models"

// Widget de sessão: avatar redondo + usuário, distro, window manager e tempo de sessão.
Box {
  id: root

  // ================= CONFIGURAÇÕES =================
  // "side"    = avatar à esquerda, lista ao lado dele
  // "stacked" = avatar em cima, lista embaixo
  property string layoutMode: "side"

  // avatar (arquivo em assets/, ou caminho absoluto): png, jpg, jpeg, gif ou svg
  property string avatarFile: "avatar.png"
  property real avatarMaxSize: 110
  property real avatarWidthShare: 0.4        // no modo "side": fração da largura que o avatar pode ocupar
  property real avatarGap: 30                // espaço entre o avatar e a lista

  // o que mostrar
  property bool showUser: true
  property bool showDistro: true
  property bool showWm: true
  property bool showSession: true

  // textos (vazio = detecta sozinho)
  property string userName: ""
  property string distroName: ""
  property string wmName: ""
  property string distroKey: "PRETTY_NAME"      // campo do /etc/os-release: PRETTY_NAME | NAME | ID

  // ícones (arquivos em assets/)
  property string userIcon: "profile_user.svg"
  property string distroIcon: "arch-linux.svg"
  property string wmIcon: "profile_window.svg"
  property string sessionIcon: "profile_session.svg"

  // visual
  property real iconSize: 18
  property real fontSize: 12
  property color textColor: "white"
  property color iconColor: "white"
  property real rowHeight: 28
  property real rowSpacing: 4
  // =================================================

  readonly property bool side: layoutMode === "side"

  function asset(name) {
    return "file://" + Quickshell.shellPath("assets/" + name)
  }

  function toUrl(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  // ---------- dados ----------
  readonly property string detectedUser: Quickshell.env("USER") || ""

  readonly property string detectedWm: {
    const d = Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP") || ""
    if (d !== "") return d
    return Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "Hyprland" : ""
  }

  property string detectedDistro: ""
  property real sessionStart: 0               // epoch, em segundos

  Process {
    id: osRelease
    command: ["cat", "/etc/os-release"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
          const m = lines[i].match(/^([A-Z_]+)=(.*)$/)
          if (m && m[1] === root.distroKey) {
            root.detectedDistro = m[2].replace(/^["']|["']$/g, "")
            return
          }
        }
      }
    }
  }

  Process {
    id: sessionProc
    command: ["sh", "-c",
      'ts=$(loginctl show-session "${XDG_SESSION_ID:-}" -p Timestamp --value 2>/dev/null); ' +
      '[ -z "$ts" ] && ts=$(loginctl show-user "$USER" -p Timestamp --value 2>/dev/null); ' +
      '[ -n "$ts" ] && date -d "$ts" +%s']
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const v = parseInt(text.trim())
        if (!isNaN(v)) root.sessionStart = v
      }
    }
  }

  // atualiza a cada minuto, e só enquanto a caixa está visível
  SystemClock {
    id: clock
    enabled: root.visible
    precision: SystemClock.Minutes
  }

  readonly property real elapsed:
    sessionStart > 0 ? Math.max(0, clock.date.getTime() / 1000 - sessionStart) : -1

  function fmtElapsed(sec) {
    if (sec < 0) return "—"
    const d = Math.floor(sec / 86400)
    const h = Math.floor((sec % 86400) / 3600)
    const m = Math.floor((sec % 3600) / 60)
    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + m + "min"
    return m + "min"
  }

  readonly property var entries: {
    const e = []
    if (showUser)    e.push({ icon: userIcon,    text: userName !== "" ? userName : detectedUser })
    if (showDistro)  e.push({ icon: distroIcon,  text: distroName !== "" ? distroName : detectedDistro })
    if (showWm)      e.push({ icon: wmIcon,      text: wmName !== "" ? wmName : detectedWm })
    if (showSession) e.push({ icon: sessionIcon, text: fmtElapsed(elapsed) })
    return e
  }

  // ---------- visual ----------
  readonly property real innerW: width - 2 * padding
  readonly property real innerH: height - 2 * padding

  readonly property real avatarSize: Math.max(0, side
    ? Math.min(innerH, innerW * avatarWidthShare, avatarMaxSize)
    : Math.min(innerW, avatarMaxSize))

  Item {
    id: content
    anchors.fill: parent

    // avatar redondo
    ClippingRectangle {
      id: avatarCircle
      x: root.side ? 0 : (content.width - width) / 2
      y: root.side ? (content.height - height) / 2 : 0
      width: root.avatarSize
      height: width
      radius: width / 2
      color: "#b8b8b8"
      antialiasing: true

      AnimatedImage {
        id: avatar
        anchors.fill: parent
        source: root.avatarFile === "" ? ""
                : root.avatarFile.startsWith("/") ? root.toUrl(root.avatarFile)
                : root.asset(root.avatarFile)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        playing: root.visible
        sourceSize: Qt.size(width * 2, height * 2)
        visible: status === Image.Ready
      }

      // se a imagem não existir, mostra a inicial do usuário
      Text {
        anchors.centerIn: parent
        visible: !avatar.visible
        text: (root.userName !== "" ? root.userName : root.detectedUser).charAt(0).toUpperCase()
        font.pixelSize: root.avatarSize * 0.45
        font.bold: true
        color: "#666666"
      }
    }

    // lista: ícone + texto
    Column {
      id: list
      x: root.side ? root.avatarSize + root.avatarGap : 0
      y: root.side ? (content.height - height) / 2 : root.avatarSize + root.avatarGap
      width: Math.max(0, content.width - x)
      spacing: root.rowSpacing

      Repeater {
        model: root.entries

        delegate: Item {
          id: row
          required property var modelData
          width: list.width
          height: root.rowHeight

          Icon {
            id: ico
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            size: root.iconSize
            color: root.iconColor
            source: root.asset(row.modelData.icon)
          }

          Text {
            anchors.left: ico.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.text
            font.pixelSize: root.fontSize
            font.bold: false
            color: root.textColor
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
