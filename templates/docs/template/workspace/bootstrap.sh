#!/usr/bin/env bash
# Arma (o actualiza) el workspace en macOS / Linux (o Git Bash en Windows).
#
#   git clone <url>/docs.git ~/dev/<org>/docs
#   bash ~/dev/<org>/docs/workspace/bootstrap.sh
#
# La raíz del workspace es la carpeta que contiene a docs/. Es idempotente:
# clona los repos de repos.txt que falten y refresca los archivos de contexto
# de la raíz, backend/ y frontend/ (correrlo después de cada `git pull` de docs
# que cambie docs/workspace/). Nunca toca un repo que ya existe.
set -euo pipefail

ws="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # <raíz>/docs/workspace
root="$(cd "$ws/../.." && pwd)"

case "$(echo "$root" | tr '[:upper:]' '[:lower:]')" in
  *onedrive*|*dropbox*|*icloud*|*mobile\ documents*)
    echo "El workspace está dentro de una carpeta sincronizada ($root). Movelo, p. ej. a ~/dev/<org>." >&2
    exit 1 ;;
esac
echo "Workspace: $root"

mkdir -p "$root/backend" "$root/frontend" "$root/worktrees"

# 1) Repos
while read -r dir url; do
  [[ -z "${dir:-}" || "$dir" == \#* ]] && continue
  dest="$root/$dir"
  if [[ -d "$dest/.git" ]]; then echo "  ok      $dir"; continue; fi
  echo "  clonar  $dir"
  git clone --quiet "$url" "$dest" || echo "  AVISO: no se pudo clonar $url (¿acceso al repo o clave SSH?)" >&2
done < "$ws/repos.txt"

# 2) Contexto de agentes en la raíz, backend/ y frontend/.
#    CLAUDE.md importa la fuente versionada (un `git pull` de docs alcanza);
#    AGENTS.md es una copia para herramientas que no siguen imports (Codex).
aviso='<!-- Generado por docs/workspace/bootstrap: no editar. Se cambia en docs/workspace/ con un MR/PR. -->'
capa() {  # <carpeta destino> <fuente relativa a workspace/> <import para CLAUDE.md>
  printf '%s\n' "$3" > "$1/CLAUDE.md"
  { printf '%s\n\n' "$aviso"; cat "$ws/$2"; } > "$1/AGENTS.md"
}
capa "$root"          AGENTS.md          "@docs/workspace/CLAUDE.md"
capa "$root/backend"  backend/AGENTS.md  "@../docs/workspace/backend/AGENTS.md"
capa "$root/frontend" frontend/AGENTS.md "@../docs/workspace/frontend/AGENTS.md"
echo "Contexto de agentes actualizado en la raíz, backend/ y frontend/."
echo "Listo. Siguiente: leer docs/workspace/README.md."
