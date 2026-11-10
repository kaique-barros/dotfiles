//@ pragma UseQApplication


import "components/bar"
import "components/theme"

import Quickshell
import QtQml

ShellRoot {
  id: root

  // Tema padrão: o id do wallpaper no Wallpaper Engine (ex.: "1845706469").
  // Só vale enquanto não houver um tema salvo (o seletor, Super+T, salva a escolha em
  // ~/.local/state/quickshell/theme). Lê themes/<id>.json; "" ou um id sem arquivo = cores e assets padrão.
  // Para testar sem salvar nada: QS_THEME=1845706469 qs
  readonly property string themeId: "3828716991"

  Binding {
    target: Theme
    property: "defaultId"
    value: root.themeId
  }

  Bar {}
}
