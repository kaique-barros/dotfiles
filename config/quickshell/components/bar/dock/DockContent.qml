import QtQuick
import QtQuick.Layouts
import Quickshell

import "../models"
import "."

Item {
  id: root

  required property var canva
  required property var barDrawer

  // Largura e altura da dock
  width: canva.dockSize
  height: canva.height - canva.topSize - canva.bottomSize
  y: canva.topSize

  // Deslocamento para animar junto com a expansão da dock
  // Quando inativa, fica na posição -canva.dockSize (oculta atrás da barra)
  x: barDrawer.dockActive ? canva.leftSize : (canva.leftSize - canva.dockSize)
  visible: barDrawer.dockSize > 0.5 || barDrawer.dockActive
  clip: true

  Behavior on x {
    NumberAnimation {
      duration: canva.animationTime
      easing.type: barDrawer.dockActive ? Easing.OutCubic : Easing.InCubic
    }
  }

  // ================= 1. RETÂNGULO SEPARADOR COM SOMBRA INTERNA =================
  // Retângulo com cantos arredondados e sombra interna separando o conteúdo da dock
  Item {
    id: separatorContainer
    anchors.fill: parent
    anchors.topMargin: 10
    anchors.bottomMargin: 10
    anchors.leftMargin: 8
    anchors.rightMargin: 12

    Rectangle {
      id: separatorBg
      anchors.fill: parent
      radius: canva.internalRadius + 4
      color: "transparent"
      border.color: "#e2e5ec"
      border.width: 1
    }

    InnerShadow {
      anchors.fill: parent
      radius: canva.internalRadius + 4
      size: 10
      color: "black"
      strength: 0.22
    }
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

          // Seção de Controle de Volume por App no canto superior direito
          AppVolumeSection {
            id: appVolumeWidget
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
          }

          // Título sutil da página 1 (multimedia)
          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 2

            Text {
              text: "MULTIMEDIA"
              font.pixelSize: 12
              font.bold: true
              font.letterSpacing: 1.5
              color: "#344054"
            }

            Text {
              text: "Painel de áudio e mídias"
              font.pixelSize: 10
              color: "#667085"
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

          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 2

            Text {
              text: "PÁGINA 2"
              font.pixelSize: 12
              font.bold: true
              font.letterSpacing: 1.5
              color: "#344054"
            }

            Text {
              text: "Seção reservada para novos módulos"
              font.pixelSize: 10
              color: "#667085"
            }
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
              text: "Conteúdo da Página 2"
              font.pixelSize: 11
              color: "#98a2b3"
            }
          }
        }

        // ================= PÁGINA 3: ESTRUTURA DISPONÍVEL =================
        Item {
          id: page3
          x: 0
          y: pageView.height * 2
          width: pageView.width
          height: pageView.height

          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 2

            Text {
              text: "PÁGINA 3"
              font.pixelSize: 12
              font.bold: true
              font.letterSpacing: 1.5
              color: "#344054"
            }

            Text {
              text: "Seção reservada para novos módulos"
              font.pixelSize: 10
              color: "#667085"
            }
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
