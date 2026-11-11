import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Servidor de notificações do shell (substitui o swaync/mako/dunst: só um programa pode ser o dono do serviço).
//
//  - notificação nova aparece no canto superior direito e some sozinha depois de um tempo, mas continua guardada;
//  - passar o mouse numa notificação expande ela e mostra o X;
//  - sem nenhuma notificação na tela, encostar o mouse no canto superior direito lista todas as que não foram fechadas.
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
  readonly property bool showList: listOpen && !hasToasts && total > 0

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

    // canto superior direito: encostar aqui abre a lista (só existe quando há o que listar)
    Item {
      id: hot
      property bool hovered: hotHover.hovered
      anchors.top: parent.top
      anchors.right: parent.right
      width: (root.total > 0 && !root.hasToasts) ? root.bar.notifHotSize : 0
      height: width

      HoverHandler { id: hotHover; onHoveredChanged: root.updateList() }
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

        Repeater {
          model: root.showList ? server.trackedNotifications : root.visibleToasts

          delegate: NotificationCard {
            required property var modelData
            width: stack.width
            bar: root.bar
            notification: modelData
            autoHide: !root.showList
            onTimedOut: root.removeToast(modelData)
          }
        }
      }
    }
  }
}
