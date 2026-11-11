import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Servidor de notificações do shell (substitui o swaync/mako/dunst: só um programa pode ser o dono do serviço).
//
//  - notificação nova aparece no canto superior direito e some sozinha depois de um tempo, mas continua no histórico;
//  - passar o mouse numa notificação expande ela e mostra o X; fechar um toast só o esconde (fica no histórico);
//  - sem toasts na tela, encostar o mouse no extremo do canto superior direito abre o histórico;
//    lá o X apaga a notificação de vez (e "Limpar tudo" apaga todas).
// Tamanhos, tempos e cores ficam no bloco TEMA do Bar.qml (notif*).
Scope {
  id: root

  required property var bar

  // toasts em exibição (mais nova primeiro); as já escondidas continuam em server.trackedNotifications
  property var toasts: []
  readonly property var visibleToasts: toasts.filter(n => n).slice(0, bar.notifMaxToasts)
  readonly property bool hasToasts: visibleToasts.length > 0
  readonly property int total: server.trackedNotifications.values.length

  property bool listOpen: false
  readonly property bool wantList: listOpen && !hasToasts && total > 0

  // o histórico só sai de cena depois da animação de saída dos cartões
  property bool showList: false
  property bool listLeaving: false
  onWantListChanged: {
    if (wantList) { listHide.stop(); listLeaving = false; showList = true }
    else if (hasToasts || total === 0) { listHide.stop(); listLeaving = false; showList = false }
    else if (showList) { listLeaving = true; listHide.restart() }
  }
  Timer { id: listHide; interval: 360; onTriggered: { root.showList = false; root.listLeaving = false } }

  function clearAll() {
    const all = server.trackedNotifications.values.slice()
    for (let i = 0; i < all.length; i++) all[i].dismiss()   // some de uma vez
  }

  function removeToast(n) { toasts = toasts.filter(x => x && x !== n) }

  function updateList() {
    if (hasToasts || total === 0) { listClose.stop(); listOpen = false; return }
    if (hot.hovered || viewHover.hovered) { listClose.stop(); listOpen = true }
    else listClose.restart()
  }
  onHasToastsChanged: updateList()
  onTotalChanged: updateList()

  Timer { id: listClose; interval: 400; onTriggered: root.listOpen = false }

  NotificationServer {
    id: server
    keepOnReload: true
    bodySupported: true
    bodyMarkupSupported: true
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true

    onNotification: (notification) => {
      notification.tracked = true
      notification.closed.connect(() => root.removeToast(notification))
      root.toasts = [notification].concat(root.toasts.filter(x => x && x !== notification))
      root.listOpen = false
    }
  }

  PanelWindow {
    id: win

    anchors { top: true; right: true; bottom: true }
    implicitWidth: root.bar.notifWidth + 2 * root.bar.notifMargin
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    // só as notificações e o cantinho recebem o mouse; o resto da janela é transparente para os cliques
    mask: Region {
      Region { item: viewport }
      Region { item: hot }
    }

    // canto superior direito: zona de detecção maior (o ponteiro parado na borda não gera novos eventos),
    // mas só conta como "encostou" quando o ponteiro está nos notifHotSize px do extremo.
    Item {
      id: hot
      property bool hovered: false
      readonly property real zone: 24
      anchors.top: parent.top
      anchors.right: parent.right
      width: (root.total > 0 && !root.hasToasts) ? zone : 0
      height: width

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        function check() {
          hot.hovered = mouseX >= width - root.bar.notifHotSize && mouseY <= root.bar.notifHotSize
          root.updateList()
        }
        onPositionChanged: check()
        onEntered: check()
        onExited: { hot.hovered = false; root.updateList() }
      }
    }

    Flickable {
      id: viewport
      x: win.width - width - root.bar.notifMargin
      y: root.bar.notifMargin
      width: root.bar.notifWidth
      height: Math.min(stack.height, win.height - 2 * root.bar.notifMargin)
      contentWidth: width
      contentHeight: stack.height
      interactive: contentHeight > height
      boundsBehavior: Flickable.StopAtBounds
      clip: true

      HoverHandler { id: viewHover; onHoveredChanged: root.updateList() }

      Column {
        id: stack
        width: viewport.width
        spacing: root.bar.notifGap

        // histórico: apagar tudo
        Rectangle {
          visible: root.showList
          width: stack.width
          height: visible ? 30 : 0
          radius: root.bar.notifRadius
          color: clearArea.containsMouse ? root.bar.dangerColor : root.bar.notifBackgroundColor
          border.width: 1
          border.color: root.bar.notifBorderColor

          Text {
            anchors.centerIn: parent
            text: "Limpar tudo (" + root.total + ")"
            font.pixelSize: root.bar.fontSize
            color: clearArea.containsMouse ? root.bar.notifBackgroundColor : root.bar.notifMutedColor
          }
          MouseArea {
            id: clearArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearAll()
          }
        }

        Repeater {
          model: root.showList ? server.trackedNotifications : root.visibleToasts

          delegate: NotificationCard {
            required property var modelData
            required property int index
            enterDelay: root.showList ? Math.min(index, 8) * 45 : 0
            width: stack.width
            bar: root.bar
            notification: modelData
            autoHide: !root.showList
            inHistory: root.showList
            leaveNow: root.listLeaving
            leaveDelay: Math.min(index, 8) * 25
            onTimedOut: root.removeToast(modelData)
          }
        }
      }
    }
  }
}
