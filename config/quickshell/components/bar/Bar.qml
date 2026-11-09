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
  property int internalRadius: 20

  // ================= CONFIGURAÇÕES GLOBAIS UNIFICADAS =================
  property int dockSize: 650
  property int animationTime: 250
  property int dockAnimationTime: animationTime
  property color frameColor: "white"
  property url splatterSource: "file://" + Quickshell.shellPath("assets/splatter.png")
  property real splatterOpacity: 0.2

  property color itemBackgroundColor: "gray"
  property real itemBackgroundOpacity: 1
  property color itemFillColor: Qt.rgba(itemBackgroundColor.r, itemBackgroundColor.g, itemBackgroundColor.b, itemBackgroundOpacity)
  property real pillThickness: 40
  // ====================================================================
  
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: dockContent.launcherActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
        frameColor: canva.frameColor
        popupWidth: 30
        popupHeight: 90
        offset: barDrawer.dockSize
        animationTime: canva.animationTime
        splatterSource: canva.splatterSource
        splatterOpacity: canva.splatterOpacity
        open: barDrawer.dockActive || archIcon.hovered || hovered

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

      WifiPopup {
        id: wifiPopup
        bar: canva
        frameColor: canva.frameColor
        splatterSource: canva.splatterSource
        splatterOpacity: canva.splatterOpacity
        offset: barDrawer.dockSize
        animationTime: canva.animationTime
        open: connectivity.openIndex === 0
        pos: connectivity.popupCenter - popupHeight / 2
      }

      BluetoothPopup {
        id: btPopup
        bar: canva
        frameColor: canva.frameColor
        splatterSource: canva.splatterSource
        splatterOpacity: canva.splatterOpacity
        offset: barDrawer.dockSize
        animationTime: canva.animationTime
        open: connectivity.openIndex === 1
        pos: connectivity.popupCenter - popupHeight / 2
      }

      PowerPopup {
        id: powerPopup
        bar: canva
        frameColor: canva.frameColor
        splatterSource: canva.splatterSource
        splatterOpacity: canva.splatterOpacity
        offset: barDrawer.dockSize
        animationTime: canva.animationTime
        open: connectivity.openIndex === 2
        pos: connectivity.popupCenter - popupHeight / 2
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

  // ================= CONTROLES NO LADO DIREITO =================
  RightControlsBar {
    id: rightControlsBar
    bar: canva
    edge: "right"
    z: 100
    frameColor: canva.frameColor
    splatterSource: canva.splatterSource
    splatterOpacity: canva.splatterOpacity
    dockActive: barDrawer.dockActive
    edgeHovered: edgeHover.hovered
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
    offset: barDrawer.dockSize
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

  Workspaces {
    bar: canva
    edge: "left"
    align: "start"
    pos: 0
    offset: barDrawer.dockSize
    animationTime: canva.animationTime
  }

  Tray {
    id: tray
    bar: canva
    edge: "left"
    align: "end"
    pos: 10
    z: 10
    offset: barDrawer.dockSize
    animationTime: canva.animationTime
  }

  Battery {
    id: battery
    bar: canva
    edge: "left"
    align: "end"
    pos: 10 + tray.collapsedLength
    offset: barDrawer.dockSize
    animationTime: canva.animationTime
    enabled: !tray.open
    opacity: tray.open ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: tray.expandDuration } }

  }

  Clock {
    id: clock
    bar: canva
    edge: "left"
    align: "end"
    pos: battery.pos + battery.length + 4
    offset: barDrawer.dockSize
    animationTime: canva.animationTime
    enabled: !tray.open
    opacity: tray.open ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: tray.expandDuration } }

  }

  Connectivity {
    id: connectivity
    bar: canva
    edge: "left"
    align: "end"
    pos: Math.max(clock.pos + clock.length - 8,       // posição normal, acima do relógio
                  tray.pos + tray.length - 8)
    offset: barDrawer.dockSize
    animationTime: canva.animationTime
    popupList: [wifiPopup, btPopup, powerPopup]
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
      item: rightControlsBar
    }

    Region { intersection: Intersection.Combine; item: wifiPopup }
    Region { intersection: Intersection.Combine; item: btPopup }
    Region { intersection: Intersection.Combine; item: powerPopup }
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
