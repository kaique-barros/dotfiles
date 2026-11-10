//@ pragma UseQApplication


import "components/bar"
import "components/theme"

import Quickshell
import QtQml

ShellRoot {
  id: root

  // Tema em uso: o id do wallpaper no Wallpaper Engine (ex.: "1845706469").
  // Lê themes/<id>.json; "" ou um id sem arquivo = cores e assets padrão.
  // Dá para trocar sem editar o arquivo: QS_THEME=1845706469 qs
  readonly property string themeId: Quickshell.env("QS_THEME") || ""

  Binding {
    target: Theme
    property: "currentId"
    value: root.themeId
  }

  Bar {}
}
