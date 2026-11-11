import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Uma notificação. Fechada, todas têm a mesma altura (bar.notifHeight);
// com o mouse em cima expande para mostrar o conteúdo inteiro e aparece o X para fechar.
Item {
  id: card

  required property var notification     // Quickshell.Services.Notifications.Notification
  property var bar
  property bool autoHide: false          // toast: some sozinha depois de um tempo (continua na lista)
  property bool inHistory: false         // no histórico o X apaga de vez; no toast só esconde (continua no histórico)
  signal timedOut()

  readonly property bool critical: notification.urgency === NotificationUrgency.Critical
  readonly property bool expanded: hover.hovered
  readonly property real pad: bar.notifPadding

  readonly property string iconSource: {
    const n = notification
    if (n.image && n.image !== "") return n.image
    if (n.appIcon && n.appIcon !== "")
      return n.appIcon.startsWith("/") ? "file://" + n.appIcon : Quickshell.iconPath(n.appIcon, true)
    return ""
  }

  readonly property real expandedHeight:
    Math.min(bar.notifMaxHeight, Math.max(bar.notifHeight, textColumn.implicitHeight + 2 * pad))

  width: parent ? parent.width : bar.notifWidth
  height: expanded ? expandedHeight : bar.notifHeight
  Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  HoverHandler { id: hover }

  // ---- entrada: vem do lado direito e desce até o lugar (toast novo e abertura do histórico) ----
  property int enterDelay: 0               // escalonamento no histórico (ms)
  property real slideX: width * 0.6
  property real slideY: -24
  opacity: 0
  transform: Translate { x: card.slideX; y: card.slideY }

  SequentialAnimation {
    id: enterAnim
    running: false
    PauseAnimation { duration: card.enterDelay }
    ParallelAnimation {
      NumberAnimation { target: card; property: "slideX"; to: 0; duration: 320; easing.type: Easing.OutCubic }
      NumberAnimation { target: card; property: "slideY"; to: 0; duration: 380; easing.type: Easing.OutCubic }
      NumberAnimation { target: card; property: "opacity"; to: 1; duration: 220 }
    }
  }
  Component.onCompleted: enterAnim.start()

  // ---- saída: faz o caminho inverso (sobe e vai para a direita) e só então age ----
  property int leaveDelay: 0
  property bool leaveNow: false            // o histórico fechando manda todos saírem
  property string exitAction: "hide"       // "hide" = só avisa o dono (timedOut); "dismiss" = apaga a notificação; "none" = só some
  property bool leaving: false

  function leave(action) {
    if (leaving) return
    leaving = true
    exitAction = action
    enterAnim.stop()
    exitAnim.start()
  }
  onLeaveNowChanged: if (leaveNow) leave("none")

  SequentialAnimation {
    id: exitAnim
    running: false
    PauseAnimation { duration: card.leaveDelay }
    ParallelAnimation {
      NumberAnimation { target: card; property: "slideX"; to: card.width * 0.6; duration: 260; easing.type: Easing.InCubic }
      NumberAnimation { target: card; property: "slideY"; to: -24; duration: 260; easing.type: Easing.InCubic }
      NumberAnimation { target: card; property: "opacity"; to: 0; duration: 220 }
    }
    ScriptAction {
      script: {
        if (card.exitAction === "dismiss") card.notification.dismiss()
        else if (card.exitAction === "hide") card.timedOut()
      }
    }
  }

  Timer {
    interval: card.notification.expireTimeout > 0 ? card.notification.expireTimeout * 1000 : card.bar.notifTimeout
    running: card.autoHide && !card.critical && !card.expanded && !card.leaving
    onTriggered: card.leave("hide")
  }

  Rectangle {
    anchors.fill: parent
    radius: card.bar.notifRadius
    color: card.bar.notifBackgroundColor
    border.width: 1
    border.color: card.critical ? card.bar.dangerColor : card.bar.notifBorderColor
  }

  // clicar na notificação aciona a ação padrão do app, se existir
  MouseArea {
    anchors.fill: parent
    onClicked: {
      const acts = card.notification.actions
      for (let i = 0; i < acts.length; i++) {
        if (acts[i].identifier === "default") { acts[i].invoke(); break }
      }
    }
  }

  Image {
    id: icon
    visible: card.iconSource !== ""
    x: card.pad
    y: card.pad
    width: card.bar.notifIconSize
    height: width
    source: card.iconSource
    sourceSize: Qt.size(width * 2, height * 2)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
  }

  Column {
    id: textColumn
    x: card.pad + (icon.visible ? icon.width + card.pad : 0)
    y: card.pad
    width: card.width - x - card.pad - (card.expanded ? closeButton.width + 4 : 0)
    spacing: 2

    Text {
      width: parent.width
      visible: card.expanded && text !== ""
      text: card.notification.appName
      font.pixelSize: card.bar.fontSize - 1
      color: card.bar.notifMutedColor
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: card.notification.summary
      font.pixelSize: card.bar.fontSize + 1
      font.bold: true
      color: card.bar.notifTextColor
      wrapMode: Text.WordWrap
      maximumLineCount: card.expanded ? 1000 : 1
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: card.notification.body
      textFormat: Text.StyledText
      font.pixelSize: card.bar.fontSize
      color: card.bar.notifMutedColor
      wrapMode: Text.WordWrap
      maximumLineCount: card.expanded ? 1000 : 1
      elide: Text.ElideRight
    }
  }

  // X (só com o mouse em cima): no toast esconde; no histórico apaga
  Rectangle {
    id: closeButton
    visible: card.expanded
    width: 22
    height: 22
    radius: 11
    x: card.width - width - 8
    y: 8
    color: closeArea.containsMouse ? card.bar.dangerColor : card.bar.notifCloseColor

    Text {
      anchors.centerIn: parent
      text: "✕"
      font.pixelSize: 11
      color: closeArea.containsMouse ? card.bar.notifBackgroundColor : card.bar.notifTextColor
    }

    MouseArea {
      id: closeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: card.leave(card.inHistory ? "dismiss" : "hide")
    }
  }
}
