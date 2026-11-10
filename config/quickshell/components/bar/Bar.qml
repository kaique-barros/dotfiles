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

  // ====================================================================
  //  PALETA: 3 cores base do shell. Troque aqui e tudo acompanha.
  //  Hover, divisores, texto secundário, trilhos etc. são calculados
  //  misturando estas cores entre si. (Quer mais cores? Declare cor4, cor5...)
  // ====================================================================
  property color cor1: "#ffffff"                  // hoje: moldura, fundo dos popups e da dock
  property color cor2: "#555555"                  // hoje: pílulas e caixas (workspaces, tray, conectividade)
  property color cor3: "#000000"                  // hoje: texto e ícones

  // cores de estado (fora da paleta)
  property color accentColor: "#12b76a"           // ativo / conectado / selecionado / bateria cheia
  property color dangerColor: "#d92d20"           // erro / bateria baixa / mudo
  property color warningColor: Qt.hsla((dangerColor.hslHue + 0.11) % 1, dangerColor.hslSaturation, dangerColor.hslLightness)   // bateria média (sai do dangerColor)

  // mistura a com b: t = 0 devolve a, t = 1 devolve b
  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
  }

  // ---------- tamanhos base: o resto deriva destes dois ----------
  property real fontSize: 12                      // texto base (linhas dos popups, bateria)
  property real iconSize: 20                      // ícone base (conectividade)

  // ================= CONFIGURAÇÕES GLOBAIS UNIFICADAS =================
  property int dockSize: 650
  property int animationTime: 250
  property int dockAnimationTime: animationTime
  property color frameColor: cor1
  property url splatterSource: "file://" + Quickshell.shellPath("assets/splatter.png")
  property real splatterOpacity: 0.2

  property color itemBackgroundColor: cor2
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
  property color iconColor: cor3               // cor padrão dos ícones sobre a barra
  property color barTextColor: cor3            // cor padrão dos textos sobre a barra

  // ---------- itens da barra ----------
  // setinha e logo
  property real archIconSize: leftSize - 17
  property color archIconColor: iconColor
  property real dockArrowSize: iconSize - 5
  property color dockArrowColor: iconColor

  // workspaces
  property real wsDotSize: 12
  property real wsDotSpacing: 6
  property color wsInactiveColor: mix(cor2, cor1, 0.6)
  property real wsActiveSize: 28
  property color wsActiveColor: cor3
  property color wsIconColor: cor1             // ícone da workspace ativa
  property real wsIconSize: iconSize - 4

  // bandeja (tray)
  property real trayRadius: 10
  property int trayColumns: 2
  property int trayRows: 2
  property real trayGap: 4
  property real trayIconSize: iconSize + 6                  // ícones com a bandeja aberta
  property real traySpacing: 10

  // bateria
  property color batteryColor: cor3            // ícone entre o amarelo e 100%
  property color batteryTextColor: barTextColor
  property int batteryLowThreshold: 20
  property int batteryMediumThreshold: 40
  property real batteryIconSize: iconSize - 2
  property real batterySpacing: 3
  property real batteryFontSize: fontSize
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
  property real connIconSize: iconSize
  property real connIconSpacing: 10
  property real connHoverScale: 1.3
  property color connIconColor: iconColor

  // ---------- popups (wifi / bluetooth / energia) ----------
  property color popupTitleColor: cor3       // título (Wi-Fi, Bluetooth, Energia)
  property color popupTextColor: cor3        // texto das linhas
  property color popupMutedColor: mix(cor3, cor1, 0.4)       // texto secundário (sinal, status, avisos)
  property color toggleOffColor: mix(cor1, cor3, 0.18)        // switch desligado
  property color toggleKnobColor: cor1         // bolinha do switch
  property color popupHoverColor: mix(cor1, cor3, 0.08)
  property color popupDividerColor: mix(cor1, cor3, 0.2)
  property real popupTitleFontSize: fontSize + 1
  property real popupRowFontSize: fontSize
  property real popupSubFontSize: fontSize - 1
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
  property color osdColor: cor3              // cor base do volume/brilho
  property color osdIconColor: osdColor
  property color osdTextColor: osdColor           // porcentagem
  property color osdFillColor: osdColor           // parte preenchida do slider
  property color osdKnobBorderColor: cor1
  property color osdTrackColor: mix(cor1, cor3, 0.1)         // trilho do slider
  property color osdKnobColor: cor3
  property color osdKnobMutedColor: mix(cor3, cor1, 0.5)
  property color osdDividerColor: mix(cor1, cor3, 0.4)
  property real osdFontSize: fontSize - 2
  property real osdWidthBoth: 110                 // largura com volume e brilho
  property real osdWidthSingle: 52                // largura com um só
  property real osdHeight: 210
  property real osdPadding: 6
  // ====================================================================
  
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: (dockContent.launcherActive || dockContent.homeKeysActive)
                               ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
