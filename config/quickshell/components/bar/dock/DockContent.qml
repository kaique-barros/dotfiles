import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "../models"
import "."

Item {
  id: root

  required property var canva
  required property var barDrawer
  readonly property bool homeKeysActive: barDrawer.dockActive && pageView.currentPage === 0

  // Largura e altura da dock
  width: canva.dockSize
  height: canva.height
  y: 0

  x: barDrawer.dockSize - width
  visible: barDrawer.dockSize > 0.5
  clip: true

  focus: barDrawer.dockActive

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: (event) => {
    if (!barDrawer.dockActive) return

    if (event.key === Qt.Key_F) {
      root.nextPage()
      event.accepted = true
    } else if (event.key === Qt.Key_G) {
      root.prevPage()
      event.accepted = true
    }
  }


  function nextPage() { pageView.currentPage = Math.min(pageView.totalPages - 1, pageView.currentPage + 1) }
  function prevPage() { pageView.currentPage = Math.max(0, pageView.currentPage - 1) }

  // niri: `qs ipc call dock next|prev` (bind no config.kdl)
  IpcHandler {
    target: "dock"
    function next(): void { root.nextPage() }
    function prev(): void { root.prevPage() }
  }

  readonly property bool launcherActive: barDrawer.dockActive && pageView.currentPage === 1

  // ao fechar a dock, ela volta para a primeira página
  property bool resetPageOnClose: true
  onVisibleChanged: {
    if (!visible && resetPageOnClose) pageView.currentPage = 0
    if (visible) console.log("DOCK pageView h:", pageView.height, "w:", pageView.width,
                             "page2.y:", page2.y, "launcher h:", launcher.height,
                             "currentPage:", pageView.currentPage)
  }

  // ================= 1. RETÂNGULO SEPARADOR COM SOMBRA INTERNA =================
  // Retângulo com cantos arredondados e sombra interna separando o conteúdo da dock
  // sombra à direita, do topo ao fim da tela, desvanecendo para a esquerda
  Item {
    id: dockShadow
    anchors.fill: parent

    property real size: 2                                   // mesma ordem de grandeza da sombra da borda
    property real strength: 0.3
    property real reach: canva.dockSize - 6

    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: dockShadowMask
      }

      InnerShadow {
        anchors.fill: parent
        radius: canva.internalRadius                         // o mesmo raio da borda
        size: dockShadow.size
        strength: dockShadow.strength
        color: "black"
      }
    }

    // máscara: só a faixa da direita aparece, e some para a esquerda (mesmo tamanho do item mascarado)
    Item {
      id: dockShadowMask
      anchors.fill: parent
      layer.enabled: true
      visible: false

      Rectangle {
        anchors.right: parent.right
        width: dockShadow.reach
        height: parent.height
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.00) }
          GradientStop { position: 0.2; color: Qt.rgba(1, 1, 1, 0.10) }
          GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.35) }
          GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.65) }
          GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.90) }
          GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 1.00) }
        }
      }
    }
  }

  // caixa de layout do conteúdo (invisível)
  Item {
    id: separatorContainer
    anchors.fill: parent
    anchors.topMargin: 10 + canva.topSize
    anchors.bottomMargin: 10 + canva.bottomSize
    anchors.leftMargin: 8
    anchors.rightMargin: 12
  }

  // ================= 2. CONTEÚDO PRINCIPAL DA DOCK =================
  Item {
    anchors.fill: separatorContainer
    anchors.margins: 10

    // Indicador de 3 Páginas no canto esquerdo da dock (estilo bolinhas minimalistas)
    DockPageIndicator {
      id: pageIndicator
      anchors.left: parent.left
      anchors.leftMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      pageCount: 3
      currentPage: pageView.currentPage
      onPageSelected: (index) => pageView.currentPage = index
    }

    // ================= 3. CONTAINER DE PÁGINAS COM TRANSIÇÃO VERTICAL =================
    Item {
      id: pageView
      anchors.left: pageIndicator.right
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      clip: true

      property int currentPage: 0
      property int totalPages: 3

      // Suporte a passar a página com o scroll do mouse
      WheelHandler {
        onWheel: (wheel) => {
          if (wheel.angleDelta.y < 0) {
            pageView.currentPage = Math.min(pageView.totalPages - 1, pageView.currentPage + 1)
          } else {
            pageView.currentPage = Math.max(0, pageView.currentPage - 1)
          }
        }
      }

      // Pilha vertical das 3 páginas
      Item {
        id: pagesContainer
        width: parent.width
        height: parent.height * pageView.totalPages
        y: -pageView.currentPage * pageView.height

        Behavior on y {
          NumberAnimation {
            id: slide
            duration: 320
            easing.type: Easing.OutCubic
          }
        }

        // ================= PÁGINA 1: MULTIMEDIA =================
        Item {
          id: page1
          x: 0
          y: 0
          width: pageView.width
          height: pageView.height
          clip: true
          visible: pageView.currentPage === 0 || slide.running

          BoxGrid {
            id: boxGrid
            anchors.fill: parent

            columns: 6
            rows: 11
            spacing: 10
            showGrid: false                // mostra a grade para você se organizar; depois ponha false

            boxColor: canva.itemFillColor  // a mesma cor das workspaces
            boxRadius: 16

            MediaBox {
              col: 0
              row: 0
              colSpan: 3                   // largura: quantas colunas ocupa
              rowSpan: 4                   // altura: quantas linhas ocupa
            }

            RandomImageBox {
              col: 3
              row: 2
              colSpan: 3
              rowSpan: 3
              directories: ["~/Downloads/cassie_pack/"]
              active: barDrawer.dockActive
            }

            SessionBox {
              col: 3
              row: 0
              colSpan: 3
              rowSpan: 2
              avatarFile: "icon.png"      // o arquivo que você colocar em assets/
            }

            CalendarBox {
              id: calendarBox
              col: 0; row: 7; colSpan: 6; rowSpan: 4
              directory: "~/Obsidian Vault/Calendar"
              tasksFile: "~/Obsidian Vault/Tarefas.md"
              active: barDrawer.dockActive
              keysEnabled: barDrawer.dockActive && pageView.currentPage === 0
            }

          }
        }

        // ================= PÁGINA 2: ESTRUTURA DISPONÍVEL =================
        Item {
          id: page2
          x: 0
          y: pageView.height
          width: pageView.width
          height: pageView.height
          clip: true
          visible: pageView.currentPage === 1 || slide.running

          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 2
          }
          AppLauncher {
            id: launcher
            anchors.fill: parent
            active: root.launcherActive
            onLaunched: if (launcher.closeOnLaunch) root.barDrawer.dockActive = false
            onCloseRequested: root.barDrawer.dockActive = false
          }
        }

        // ================= PÁGINA 3: ESTRUTURA DISPONÍVEL =================
        Item {
          id: page3
          x: 0
          y: pageView.height * 2
          width: pageView.width
          height: pageView.height
          clip: true
          visible: pageView.currentPage === 2 || slide.running

          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 2
          }

          Rectangle {
            anchors.centerIn: parent
            width: parent.width - 40
            height: 120
            radius: 12
            color: "#f8f9fc"
            border.color: "#eaecf0"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "Conteúdo da Página 3"
              font.pixelSize: 11
              color: "#98a2b3"
            }
          }
        }
      }
    }
  }
}
