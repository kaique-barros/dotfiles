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

  property color itemBackgroundColor: "#555555"
  property real itemBackgroundOpacity: 1
  property color itemFillColor: Qt.rgba(itemBackgroundColor.r, itemBackgroundColor.g, itemBackgroundColor.b, itemBackgroundOpacity)
  property real pillThickness: 40
  // ====================================================================

  // ====================================================================
  //  TEMA: cores, fontes e tamanhos de todos os itens e popups
  //  Os módulos leem tudo daqui; só mexa em um módulo para casos especiais.
  // ====================================================================

  // ---------- fonte e cores globais ----------
  property string fontFamily: ""                  // "" = fonte padrão do sistema
  property color iconColor: "black"               // cor padrão dos ícones sobre a barra
  property color barTextColor: "black"            // cor padrão dos textos sobre a barra
  property color accentColor: "#12b76a"           // conectado / ativo / selecionado / bateria cheia
  property color warningColor: "#f5b800"          // bateria média
  property color dangerColor: "#d92d20"           // bateria baixa / volume mudo

  // ---------- itens da barra ----------
  // setinha e logo
  property real archIconSize: leftSize - 17
  property color archIconColor: iconColor
  property real dockArrowSize: 15
  property color dockArrowColor: iconColor

  // workspaces
  property real wsDotSize: 12
  property real wsDotSpacing: 6
  property color wsInactiveColor: "#b4b4b4"
  property real wsActiveSize: 28
  property color wsActiveColor: "black"
  property color wsIconColor: "white"             // ícone da workspace ativa
  property real wsIconSize: 16

  // bandeja (tray)
  property real trayRadius: 10
  property int trayColumns: 2
  property int trayRows: 2
  property real trayGap: 4
  property real trayIconSize: 26                  // ícones com a bandeja aberta
  property real traySpacing: 10

  // bateria
  property color batteryColor: "black"            // ícone entre o amarelo e 100%
  property color batteryTextColor: barTextColor
  property int batteryLowThreshold: 20
  property int batteryMediumThreshold: 40
  property real batteryIconSize: 18
  property real batterySpacing: 3
  property real batteryFontSize: 12
  property bool batteryFontBold: true

  // relógio
  property string clockFontFamily: "JetBrainsMono NF, ExtraBold"
  property real clockFontSize: 22
  property bool clockFontBold: true
  property color clockTextColor: barTextColor
  property real clockLineSpacing: -12
  property bool clockShowSeconds: true
  property real clockSecondsFontSize: 22
  property bool clockTwelveHour: false

  // conectividade (wifi / bluetooth / energia)
  property real connIconSize: 20
  property real connIconSpacing: 10
  property real connHoverScale: 1.3
  property color connIconColor: iconColor

  // ---------- popups (wifi / bluetooth / energia) ----------
  property color popupTitleColor: "#1d2939"       // título (Wi-Fi, Bluetooth, Energia)
  property color popupTextColor: "#1d2939"        // texto das linhas
  property color popupMutedColor: "#667085"       // texto secundário (sinal, status, avisos)
  property color toggleOffColor: "#d0d5dd"        // switch desligado
  property color toggleKnobColor: "white"         // bolinha do switch
  property color popupHoverColor: "#e8ebf0"
  property color popupDividerColor: "#c7cdd6"
  property real popupTitleFontSize: 13
  property real popupRowFontSize: 12
  property real popupSubFontSize: 11
  property real popupRowHeight: 30
  property real popupHeaderHeight: 28
  property real popupPadding: 8
  property int popupMaxRows: 7
  property real popupHeaderDividerRatio: 0.9      // tamanho do separador do título (relativo ao popup)
  property real popupItemDividerRatio: 0.8        // tamanho do separador entre itens
  property real popupDividerThickness: 1.5
  property real wifiPopupWidth: 230
  property real btPopupWidth: 230
  property real powerPopupWidth: 200

  // ---------- volume e brilho (lado direito) ----------
  property color osdColor: "#1e1e2e"              // cor base do volume/brilho
  property color osdIconColor: osdColor
  property color osdTextColor: osdColor           // porcentagem
  property color osdFillColor: osdColor           // parte preenchida do slider
  property color osdKnobBorderColor: "white"
  property color osdTrackColor: "#e4e4ea"         // trilho do slider
  property color osdKnobColor: "#11111b"
  property color osdKnobMutedColor: "#757575"
  property color osdDividerColor: "#9ca3af"
  property real osdFontSize: 10
  property real osdWidthBoth: 110                 // largura com volume e brilho
  property real osdWidthSingle: 52                // largura com um só
  property real osdHeight: 210
  property real osdPadding: 6
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
          color: canva.dockArrowColor
          size: canva.dockArrowSize
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
      color: canva.archIconColor
      size: canva.archIconSize
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
