import QtQuick
import Quickshell
import Quickshell.Services.UPower

import "../../theme"
import "../models"

// Ícone de bateria + porcentagem, lado a lado. Só o ícone muda de cor.
BarItemModel {
  id: root

  // ================= CONFIGURAÇÕES =================
  property color defaultColor: bar ? bar.batteryColor : "black"         // cor padrão do ícone (acima do amarelo, abaixo de 100%)
  property color lowColor: bar ? bar.dangerColor : "#d92d20"           // abaixo de lowThreshold: vermelho
  property color mediumColor: bar ? bar.warningColor : "#f5b800"        // até mediumThreshold: amarelo
  property color fullColor: bar ? bar.accentColor : "#12b76a"          // 100% ou carregando: verde
  property color textColor: bar ? bar.batteryTextColor : "black"
  property int lowThreshold: bar ? bar.batteryLowThreshold : 20
  property int mediumThreshold: bar ? bar.batteryMediumThreshold : 40

  property string iconFile: "battery.svg"
  property string chargingIconFile: "battery_charging.svg"
  property real iconSize: bar ? bar.batteryIconSize : 18
  property real spacing: bar ? bar.batterySpacing : 3                     // espaço entre ícone e texto

  property string fontFamily: bar ? bar.fontFamily : ""               // vazio = fonte padrão
  property real fontSize: bar ? bar.batteryFontSize : 12
  property bool fontBold: bar ? bar.batteryFontBold : true

  property real verticalPadding: 3             // folga acima/abaixo, ao longo da barra
  // =================================================

  readonly property var device: UPower.displayDevice
  readonly property bool present: !!device && device.isPresent

  // o UPower entrega 0..1; se vier 0..100 também funciona
  readonly property int percent: {
    const p = device ? device.percentage : 0
    return Math.round(p <= 1 ? p * 100 : p)
  }
  readonly property bool charging: !!device && device.state === UPowerDeviceState.Charging

  readonly property color iconColor:
      (charging || percent >= 100) ? fullColor
    : percent < lowThreshold       ? lowColor
    : percent <= mediumThreshold   ? mediumColor
    :                                defaultColor

  framed: false
  inset: 0
  padding: 0
  length: present ? Math.max(iconSize, label.implicitHeight) + 2 * verticalPadding : 0
  visible: thickness > 0 && present

  Row {
    anchors.centerIn: parent
    spacing: root.spacing

    Icon {
      anchors.verticalCenter: parent.verticalCenter
      size: root.iconSize
      color: root.iconColor
      source: Theme.asset(root.charging ? root.chargingIconFile : root.iconFile)
    }

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      text: root.percent
      color: root.textColor
      font.family: root.fontFamily !== "" ? root.fontFamily : Qt.application.font.family
      font.pixelSize: root.fontSize
      font.bold: root.fontBold
    }
  }
}
