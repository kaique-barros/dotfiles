#!/usr/bin/env python3

"""Adiciona as configurações do Niri aos arquivos JSON dos temas."""

import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(
        description="Adiciona configurações do Niri aos temas."
    )
    parser.add_argument(
        "--themes",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "themes",
        help="Diretório dos temas."
    )
    parser.add_argument("--border-width", type=float, default=2)
    parser.add_argument("--corner-radius", type=float, default=7)
    args = parser.parse_args()

    themes_dir = args.themes
    files = sorted(themes_dir.glob("*.json"))

    updated = 0
    unchanged = 0
    failed = 0

    for path in files:
        try:
            with path.open("r", encoding="utf-8") as file:
                data = json.load(file)

            if not isinstance(data, dict):
                raise ValueError("JSON não contém um objeto.")

            niri = data.setdefault("niri", {})

            if not isinstance(niri, dict):
                raise ValueError("A propriedade 'niri' não é um objeto.")

            changed = False

            defaults = {
                "borderWidth": args.border_width,
                "cornerRadius": args.corner_radius,
            }

            for key, value in defaults.items():
                if key not in niri:
                    niri[key] = value
                    changed = True

            if changed:
                tmp = path.with_suffix(".json.tmp")

                with tmp.open("w", encoding="utf-8") as file:
                    json.dump(data, file, indent=2, ensure_ascii=False)
                    file.write("\n")

                tmp.replace(path)
                updated += 1
                print(f"[niri] {path.name}: atualizado")
            else:
                unchanged += 1

        except (OSError, ValueError, json.JSONDecodeError) as error:
            failed += 1
            print(f"[niri] {path.name}: erro: {error}")

    print(
        f"\nTemas: {updated} atualizados, "
        f"{unchanged} já estavam configurados, "
        f"{failed} com falha."
    )

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
