import QtQuick
import Quickshell

import "../models"

// Hora em cima, minuto embaixo (e segundo, se quiser). Sem fundo.
BarItemModel {
  id: root

  // ================= CONFIGURAÇÕES =================
  property real lineSpacing: -12                 // distância entre hora e minuto (aceita negativo)
  property string fontFamily: "JetBrainsMono NF, ExtraBold"               // vazio = fonte padrão
  property real fontSize: 22
  property bool fontBold: true
  property color textColor: "black"

  property bool showSeconds: true
  property real secondsFontSize: 22            // tamanho do segundo
  property bool twelveHour: false              // 12h em vez de 24h

  property real verticalPadding: 2
  // =================================================

  framed: false
  inset: 0
  padding: 0
  length: col.implicitHeight + 2 * verticalPadding

  SystemClock {
    id: clock
    precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
  }

  function two(n) { return n < 10 ? "0" + n : "" + n }

  readonly property string hourText: two(twelveHour ? (clock.hours % 12 || 12) : clock.hours)
  readonly property string minuteText: two(clock.minutes)
  readonly property string secondText: two(clock.seconds)

  readonly property string family: fontFamily !== "" ? fontFamily : Qt.application.font.family

  Column {
    id: col
    anchors.centerIn: parent
    width: parent.width
    spacing: root.lineSpacing

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.hourText
      color: root.textColor
      font.family: root.family
      font.pixelSize: root.fontSize
      font.bold: root.fontBold
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.minuteText
      color: root.textColor
      font.family: root.family
      font.pixelSize: root.fontSize
      font.bold: root.fontBold
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      visible: root.showSeconds
      text: root.secondText
      color: root.textColor
      font.family: root.family
      font.pixelSize: root.secondsFontSize
      font.bold: root.fontBold
    }
  }
}
