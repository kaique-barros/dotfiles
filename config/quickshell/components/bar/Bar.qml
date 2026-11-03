import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

import "models"

PanelWindow {
  id: canva
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  exclusiveZone: 0
  color: 'transparent'
  
  property int topSize: 0
  property int bottomSize: 0
  property int leftSize: 60
  property int rightSize: 0
  property int internalRadius: 10
  property int dockAnimationTime: 150

  Item {
    id: globalShadowContainer
    anchors.fill: parent
    anchors.margins: -20  // Folga para o desfoque da sombra projetada

    Item {
      id: shapeSource 
      anchors.fill: parent
      anchors.margins: 20

      BarDrawer { id: barDrawer; canva: canva; animationTime: dockAnimationTime }

      PopupModel {
        id: popupB
        bar: canva
        edge: "left"
        // Mantém o popup aberto o tempo todo enquanto a dock estiver ativa
        open: barDrawer.dockActive
        frameColor: barDrawer.frameColor
        popupWidth: 30
        popupHeight: 90
        offset: barDrawer.dockActive ? 650 : 0
        animationTime: dockAnimationTime

        Icon {
          id: popupIcon
          anchors.centerIn: parent
          // Alterna dinamicamente a imagem com base no estado da dock
          source: "file://" + Quickshell.shellPath(
            barDrawer.dockActive 
              ? "assets/dock_arrow_close.svg" 
              : "assets/dock_arrow_open.svg"
          )
          color: "black"
          size: 15
        }
      }
    }

    MultiEffect {
      source: shapeSource
      anchors.fill: shapeSource
      shadowEnabled: true
      shadowColor: 'black'
      shadowBlur: 0.8
      shadowHorizontalOffset: 4
      shadowVerticalOffset: 0
    }
  }

  BarItemModel {
    id: archItem
    bar: canva
    edge: "left"
    
    // Muda a posição para o final quando a dock está ativa
    align: "center"
    pos: 10
    length: 200
    framed: false
    popup: popupB
    trigger: "hover"
    offset: barDrawer.dockActive ? 650 : 0
    animationTime: dockAnimationTime
    
    onClicked: {
      barDrawer.dockActive = !barDrawer.dockActive
      console.log("dockActive:", barDrawer.dockActive, "size:", barDrawer.dockSize)
    }

    Icon {
      anchors.centerIn: parent
      source: "file://" + Quickshell.shellPath("assets/arch-linux.svg")
      color: "black"
      size: canva.leftSize - 17
    }
  }

  ClippingRectangle {
    visible: false
    color: 'red'
    opacity: .2
    topLeftRadius: internalRadius
    bottomLeftRadius: internalRadius
    x: canva.leftSize
    y: canva.topSize
    width: canva.width - canva.leftSize - canva.rightSize
    height: canva.height - canva.topSize - canva.bottomSize
  }

  // Região clicável
  mask: Region {
    width: canva.width
    height: canva.height

    Region {
      intersection: Intersection.Subtract
      x: canva.leftSize + (barDrawer.dockActive ? barDrawer.dockSize : 0) 
      y: canva.topSize
      width: canva.width - canva.leftSize - canva.rightSize - (barDrawer.dockActive ? barDrawer.dockSize : 0) 
      height: canva.height - canva.topSize - canva.bottomSize
    }

    Region {
      intersection: Intersection.Combine
      item: popupB
    }
  }

  // Espaço reservado para a barra
  Repeater {
    model: [
      {edge: 'top', size: canva.topSize},
      {edge: 'bottom', size: canva.bottomSize},
      {edge: 'right', size: canva.rightSize},
      {edge: 'left', size: canva.leftSize}
    ]

    PanelWindow {
      property string edge: modelData.edge
      property int size: modelData.size
      anchors {
        top: edge !== 'bottom'
        bottom: edge !== 'top'
        left: edge !== 'right'
        right: edge !== 'left'
      }
      mask: Region {}
      color: 'transparent'
      
      implicitWidth: (edge === 'left' || edge === 'right') ? size : 0 
      implicitHeight: (edge === 'top' || edge === 'bottom') ? size : 0
    }
  } 
}
