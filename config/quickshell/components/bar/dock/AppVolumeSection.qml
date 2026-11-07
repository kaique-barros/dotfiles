import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

import "../models"

Item {
  id: root

  width: 290

  readonly property int itemsPerPage: 3
  property int currentPage: 0

  readonly property var streamNodes: {
    if (!Pipewire.ready || !Pipewire.nodes) return []
    const list = []
    const vals = Pipewire.nodes.values
    for (let i = 0; i < vals.length; i++) {
      const n = vals[i]
      if (n && n.isStream && n.audio) list.push(n)
    }
    return list
  }

  PwObjectTracker {
    objects: root.streamNodes
  }

  readonly property int totalStreams: streamNodes.length
  readonly property int totalPages: Math.max(1, Math.ceil(totalStreams / itemsPerPage))

  onTotalPagesChanged: {
    if (currentPage >= totalPages) currentPage = Math.max(0, totalPages - 1)
  }

  readonly property var currentStreams: {
    const start = currentPage * itemsPerPage
    return streamNodes.slice(start, start + itemsPerPage)
  }

  // altura: margens (20) + [cabeçalho se houver mais de uma página] + linhas
  readonly property int currentStreamCount: Math.min(itemsPerPage, totalStreams)
  implicitHeight: totalStreams === 0
    ? 62
    : 20 + currentStreamCount * 46 + (currentStreamCount - 1) * 6 + (totalPages > 1 ? 30 : 0)

  height: implicitHeight
  Behavior on height {
    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
  }

  // ---------- ícones ----------
  function findDesktopEntry(keys) {
    for (let i = 0; i < keys.length; i++) {
      const e = DesktopEntries.byId(keys[i]) || DesktopEntries.heuristicLookup(keys[i])
      if (e) return e
    }
    const all = DesktopEntries.applications.values
    for (let i = 0; i < all.length; i++) {
      const a = all[i]
      const name = (a.name || "").toLowerCase()
      const wm = (a.startupClass || "").toLowerCase()
      for (let j = 0; j < keys.length; j++) {
        const k = keys[j].toLowerCase()
        if (name === k || wm === k) return a
      }
    }
    return null
  }

  function resolveAppIcon(node) {
    if (!node || !node.properties) return ""
    const p = node.properties
    const names = [
      p["application.icon-name"],
      p["application.icon_name"],
      p["application.name"],
      p["application.process.binary"],
      p["node.name"]
    ].filter(v => v && typeof v === "string" && v.trim() !== "").map(v => v.trim())

    for (let i = 0; i < names.length; i++) {
      const a = Quickshell.iconPath(names[i], true)
      if (a) return a
      const b = Quickshell.iconPath(names[i].toLowerCase(), true)
      if (b) return b
    }

    const entry = findDesktopEntry(names)
    if (entry && entry.icon) {
      if (entry.icon.startsWith("/")) return "file://" + entry.icon
      const c = Quickshell.iconPath(entry.icon, true)
      if (c) return c
    }
    return ""
  }

  function volumeIconName(muted, vol) {
    if (muted) return "volume_muted"
    if (vol <= 0.001) return "volume_zero"
    if (vol < 0.5) return "volume_low"
    return "volume_high"
  }

  // ================= EFEITO "AFUNDADO" =================
  InnerShadow {
    anchors.fill: parent
    radius: 14
    size: 6
    strength: 0.28
    color: "black"
  }

  // ================= CONTEÚDO =================
  Column {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 6

    // paginação (só aparece com mais de 3 mídias)
    RowLayout {
      width: parent.width
      visible: root.totalPages > 1

      Item { Layout.fillWidth: true }

      Row {
        spacing: 4

        Rectangle {
          width: 18; height: 18; radius: 4
          color: root.currentPage > 0 ? "#d0d5dd" : "#e0e3ea"
          opacity: root.currentPage > 0 ? 1.0 : 0.4

          Text {
            anchors.centerIn: parent
            text: "‹"
            font.pixelSize: 12
            font.bold: true
            color: "#344054"
          }
          MouseArea {
            anchors.fill: parent
            enabled: root.currentPage > 0
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.currentPage = Math.max(0, root.currentPage - 1)
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: (root.currentPage + 1) + "/" + root.totalPages
          font.pixelSize: 10
          font.bold: true
          color: "#667085"
        }

        Rectangle {
          width: 18; height: 18; radius: 4
          color: root.currentPage < root.totalPages - 1 ? "#d0d5dd" : "#e0e3ea"
          opacity: root.currentPage < root.totalPages - 1 ? 1.0 : 0.4

          Text {
            anchors.centerIn: parent
            text: "›"
            font.pixelSize: 12
            font.bold: true
            color: "#344054"
          }
          MouseArea {
            anchors.fill: parent
            enabled: root.currentPage < root.totalPages - 1
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.currentPage = Math.min(root.totalPages - 1, root.currentPage + 1)
          }
        }
      }
    }

    // estado vazio
    Item {
      width: parent.width
      height: 42
      visible: root.totalStreams === 0

      Text {
        anchors.centerIn: parent
        text: "Nenhuma mídia reproduzindo"
        font.pixelSize: 10
        font.italic: true
        color: "#98a2b3"
      }
    }

    // lista (3 por página)
    Column {
      width: parent.width
      spacing: 6
      visible: root.totalStreams > 0

      Repeater {
        model: root.currentStreams

        delegate: Rectangle {
          id: appItem
          required property var modelData

          width: parent.width
          height: 46
          radius: 8
          color: "#ffffff"
          border.color: "#e2e5ec"
          border.width: 1

          readonly property var nodeAudio: modelData ? modelData.audio : null
          readonly property real appVol: nodeAudio ? nodeAudio.volume : 0
          readonly property bool appMuted: nodeAudio ? nodeAudio.muted : false
          readonly property string appName: {
            if (!modelData || !modelData.properties) return modelData ? modelData.name : ""
            return modelData.properties["application.name"] ||
                   modelData.properties["media.name"] ||
                   modelData.name
          }
          readonly property string appIconUrl: root.resolveAppIcon(modelData)

          RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            // ícone do app (sem clique); se não achar, mostra a inicial
            Rectangle {
              Layout.preferredWidth: 28
              Layout.preferredHeight: 28
              radius: 6
              color: "#f2f4f7"

              IconImage {
                id: iconImg
                anchors.centerIn: parent
                width: 20
                height: 20
                source: appItem.appIconUrl
                visible: status === Image.Ready
                opacity: appItem.appMuted ? 0.4 : 1.0
              }

              Text {
                anchors.centerIn: parent
                visible: !iconImg.visible
                text: (appItem.appName || "?").charAt(0).toUpperCase()
                font.pixelSize: 13
                font.bold: true
                color: "#344054"
              }
            }

            // nome + slider
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              RowLayout {
                Layout.fillWidth: true

                Text {
                  Layout.fillWidth: true
                  text: appItem.appName
                  font.pixelSize: 10
                  font.bold: true
                  color: appItem.appMuted ? "#98a2b3" : "#1d2939"
                  elide: Text.ElideRight
                }

                Text {
                  text: appItem.appMuted ? "Mudo" : (Math.round(appItem.appVol * 100) + "%")
                  font.pixelSize: 9
                  font.bold: true
                  color: appItem.appMuted ? "#d92d20" : "#475467"
                }
              }

              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 12

                Rectangle {
                  id: track
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: 4
                  radius: 2
                  color: "#eaecf0"

                  Rectangle {
                    height: parent.height
                    width: Math.max(0, Math.min(parent.width, parent.width * appItem.appVol))
                    radius: 2
                    color: appItem.appMuted ? "#98a2b3" : "#12b76a"
                  }

                  Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * appItem.appVol - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: appItem.appMuted ? "#667085" : "#027a48"
                    border.color: "white"
                    border.width: 1.5
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor

                  function applyPos(mouseX) {
                    if (appItem.nodeAudio) {
                      appItem.nodeAudio.volume = Math.max(0, Math.min(1.0, mouseX / track.width))
                    }
                  }

                  onPressed: (mouse) => applyPos(mouse.x)
                  onPositionChanged: (mouse) => { if (pressed) applyPos(mouse.x) }
                  onWheel: (wheel) => {
                    if (appItem.nodeAudio) {
                      const step = 0.02 * (wheel.angleDelta.y > 0 ? 1 : -1)
                      appItem.nodeAudio.volume = Math.max(0, Math.min(1.0, appItem.nodeAudio.volume + step))
                    }
                  }
                }
              }
            }

            // botão de volume / mute (mesmo comportamento do principal)
            Rectangle {
              Layout.preferredWidth: 26
              Layout.preferredHeight: 26
              radius: 6
              color: appItem.appMuted ? "#fee4e2" : "#f2f4f7"

              Icon {
                anchors.centerIn: parent
                size: 15
                color: appItem.appMuted ? "#d92d20" : "#344054"
                source: "file://" + Quickshell.shellPath(
                  "assets/" + root.volumeIconName(appItem.appMuted, appItem.appVol) + ".svg")
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (appItem.nodeAudio) appItem.nodeAudio.muted = !appItem.nodeAudio.muted
                }
              }
            }
          }
        }
      }
    }
  }
}
