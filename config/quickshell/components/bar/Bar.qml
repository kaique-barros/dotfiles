import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects

import "models"
import "modules"
import "dock"

PanelWindow {
  id: canva
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

  // ================= CONFIGURAÇÕES GLOBAIS UNIFICADAS =================
  property int dockSize: 650
  property int animationTime: 250
  property int dockAnimationTime: animationTime
  property color frameColor: "white"
  property url splatterSource: "file://" + Quickshell.shellPath("assets/splatter.png")
  property real splatterOpacity: 0.35

  property color itemBackgroundColor: "gray"
  property real itemBackgroundOpacity: 1
  property color itemFillColor: Qt.rgba(itemBackgroundColor.r, itemBackgroundColor.g, itemBackgroundColor.b, itemBackgroundOpacity)
  property real pillThickness: 40
  // ====================================================================
  
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  Item {
    id: globalShadowContainer
    anchors.fill: parent
    anchors.margins: -20  // Folga para o desfoque da sombra projetada

    Item {
      id: shapeSource 
      anchors.fill: parent
      anchors.margins: 20

      BarDrawer { id: barDrawer; canva: canva; animationTime: canva.animationTime }

      PopupModel {
        id: dockPusher
        bar: canva
        edge: "left"
        open: barDrawer.dockActive
        frameColor: canva.frameColor
        popupWidth: 30
        popupHeight: 90
        offset: barDrawer.dockActive ? canva.dockSize : 0
        animationTime: canva.animationTime
        splatterSource: canva.splatterSource
        splatterOpacity: canva.splatterOpacity

        Icon {
          id: popupIcon
          anchors.centerIn: parent
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
      shadowBlur: 0.3
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
    }
  }

  // ================= CONTEÚDO DA DOCK =================
  DockContent {
    id: dockContent
    canva: canva
    barDrawer: barDrawer
  }

  // ================= VOLUME NO LADO DIREITO =================
  RightVolumeBar {
    id: rightVolumeBar
    canva: canva
    dockActive: barDrawer.dockActive
  }

  // Detector na borda direita para disparar o volume por aproximação
  Item {
    id: rightEdgeDetector
    x: canva.width - 16
    y: 0
    width: 16
    height: canva.height
    z: 99

    HoverHandler {
      id: edgeHover
      onHoveredChanged: rightVolumeBar.edgeHovered = edgeHover.hovered
    }
  }

  BarItemModel {
    id: archIcon
    bar: canva
    edge: "left"
    align: "center"
    pos: 10
    length: 200
    framed: false
    popup: dockPusher
    trigger: "hover"
    offset: barDrawer.dockActive ? canva.dockSize : 0
    animationTime: canva.animationTime
    
    onClicked: {
      barDrawer.dockActive = !barDrawer.dockActive
    }

    Icon {
      anchors.centerIn: parent
      source: "file://" + Quickshell.shellPath("assets/arch-linux.svg")
      color: "black"
      size: canva.leftSize - 17
    }
  }

  BarItemModel {
    id: clock
    bar: canva
    pos: 40
    length: 200
    edge: 'left'
    align: 'end'
    SystemClock {
      id: sysClock
      precision: SystemClock.Seconds
    }
    Column {
      Text {
        text: sysClock.hours
        color: 'black'
      }
      Text {
        text: sysClock.minutes
        color: 'black'
      }
    }
  }

  Workspaces {
    bar: canva
    edge: "left"
    align: "start"
    pos: 0
    offset: barDrawer.dockActive ? canva.dockSize : 0     // acompanha a dock, como o archItem
    animationTime: canva.animationTime
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
      item: dockPusher
    }

    Region {
      intersection: Intersection.Combine
      item: rightEdgeDetector
    }

    Region {
      intersection: Intersection.Combine
      item: rightVolumeBar
    }
  }

  // Espaço reservado para a barra
  Repeater {
    id: safeZone
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
      exclusiveZone: size
      
      implicitWidth: (edge === 'left' || edge === 'right') ? size : 0 
      implicitHeight: (edge === 'top' || edge === 'bottom') ? size : 0
    }
  } 
}
