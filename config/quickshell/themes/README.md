# Temas

Um tema = um arquivo `themes/<id>.json`, onde `<id>` é o id do wallpaper no Wallpaper Engine
(o nome da pasta em `~/.local/share/Steam/steamapps/workshop/content/431960/`).

## Usar um tema

- **Seletor (Super+T):** abre um popup embaixo da tela com os prints dos wallpapers. `h`/`l` (ou ← →, roda do mouse,
  clique) passam de um para o outro e já trocam o tema e o wallpaper; `Esc`, `Enter` ou `q` fecham, e o tema escolhido fica.
  O atalho é `bind = $mainMod, T, exec, qs ipc call theme toggle` (também existem `theme open` e `theme close`).
- **Persistência:** a escolha é salva em `~/.local/state/quickshell/theme`. No `hyprland.conf`, em vez de iniciar o
  `linux-wallpaperengine` direto, use `exec-once = ~/.config/quickshell/tools/wallpaper.sh start`: ele sobe o engine
  com o tema salvo e o shell lê o mesmo arquivo. Monitores e opções do engine ficam em `themes/engine.conf`.
- **Padrão:** `themeId` no `shell.qml` vale só enquanto não existe tema salvo (e `DEFAULT_ID` no `engine.conf` faz o
  mesmo papel para o wallpaper). Para testar sem salvar nada: `QS_THEME=1845706469 qs`.
- Id vazio, ou sem arquivo em `themes/`, usa cores e assets padrão. Editar o json com o shell aberto aplica na hora.

## Formato

Todos os campos são opcionais; **vazio ou ausente = usar o padrão**.

```json
{
  "id": "1845706469",
  "name": "Título do wallpaper",
  "screenshot": "/caminho/do/print.png",
  "assets": "",
  "colors": { "cor1": "#ffffff", "cor2": "#555555", "cor3": "#000000", "accent": "", "danger": "" },
  "quantized": ["#112233", "..."]
}
```

- `colors`: as cores da paleta do `Bar.qml` (`cor1`..`cor3`, `accent`, `danger`).
- `assets`: pasta com ícones do tema (absoluto, com `~`, ou relativo a `themes/`).
  Cada arquivo que existir lá (mesmo nome de `assets/`, ex. `battery.svg`) tem prioridade;
  o que faltar, ou uma pasta inexistente, cai nos `assets/` padrão.
- `quantized`: cores brutas do ColorQuantizer, só para consulta. Não é lido pelo shell.
- Chaves extras que você acrescentar são mantidas pelo gerador.

## Gerar os temas

```sh
tools/gen-themes.sh                 # todos os wallpapers que ainda não têm print/tema
tools/gen-themes.sh 1845706469      # só um
tools/gen-themes.sh --force         # refaz prints e cores (mantém "assets" e "name")
```

1. O `linux-wallpaperengine --screenshot` tira um print de cada wallpaper em `themes/screenshots/<id>.png`.
   Se o engine falhar, usa o `preview.*` do próprio wallpaper (desligue com `--no-fallback`).
2. `tools/ThemeGen.qml` roda o `ColorQuantizer` do Quickshell no print e o `tools/make_theme.py`
   escolhe `cor1`/`cor2`/`cor3`/`accent` entre as cores encontradas.

As cores geradas são só um ponto de partida: um tema que já existe **nunca é sobrescrito**
sem `--force`, então pode ajustar o json à vontade.
