#!/usr/bin/env bash
# Hooks de estado (docs/03 §4, §6 y §7): reportan al tracker qué está haciendo
# la sesión, con la herramienta `report_status` de su servidor MCP.
#
#   estado.sh inicio     SessionStart      registra la sesión (en-reposo)
#   estado.sh turno      UserPromptSubmit  trabajando
#   estado.sh latido     PostToolUse       trabajando, como mucho uno por minuto
#   estado.sh espera     Notification      esperando-ok (pedido de permiso o pregunta)
#   estado.sh reposo     Stop              en-reposo + resumen del turno
#   estado.sh fin        SessionEnd        terminada + lo que quedó sólo local
#
# Nunca bloquea ni escribe en stdout (en UserPromptSubmit y SessionStart, lo
# que sale por stdout entra al contexto del modelo). Sin TRACKER_MCP_URL y
# TRACKER_TOKEN en el entorno no hace nada. Todo corre en segundo plano
# (DEV_AGENTES_ESTADO_SYNC=1 lo corre en primer plano, para los tests); los
# errores van a $DEV_AGENTES_LOG (default ~/.claude/dev-agentes/estado.log).
#
# Desactivar: DEV_AGENTES_NO_ESTADO=1.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

evento=${1:-}
[ "${DEV_AGENTES_NO_ESTADO:-}" = 1 ] && exit 0
[ -n "${TRACKER_MCP_URL:-}" ] && [ -n "${TRACKER_TOKEN:-}" ] || exit 0
command -v curl >/dev/null 2>&1 || exit 0
read_input

# Todo lo demás (git, JSON, red) corre en segundo plano y sin heredar
# stdout/stderr: Claude Code no espera al tracker, y SessionEnd tiene 1,5 s.
if [ "${DEV_AGENTES_ESTADO_SYNC:-}" != 1 ]; then
  (DEV_AGENTES_ESTADO_SYNC=1 bash "$0" "$evento" <<<"$HOOK_INPUT" >/dev/null 2>&1 &) </dev/null >/dev/null 2>&1
  exit 0
fi

session_id=$(json_get session_id)
[ -n "$session_id" ] || exit 0
cwd=$(norm_path "$(json_get cwd)")
[ -n "$cwd" ] || cwd=$(norm_path "$PWD")

case $evento in
  inicio) state=en-reposo ;;
  turno) state=trabajando ;;
  latido)
    state=trabajando
    # Como mucho un latido por minuto: el turno ya avisó que está trabajando.
    stamp="${TMPDIR:-/tmp}/dev-agentes-latido-${session_id//[^A-Za-z0-9_-]/_}"
    if [ -f "$stamp" ] && [ $(($(date +%s) - $(file_mtime "$stamp"))) -lt "${DEV_AGENTES_LATIDO_SEG:-60}" ]; then
      exit 0
    fi
    : >"$stamp" 2>/dev/null || true
    ;;
  espera) state=esperando-ok ;;
  reposo) state=en-reposo ;;
  fin) state=terminada ;;
  *) exit 0 ;;
esac

# --- Datos de la sesión ------------------------------------------------------

# Rama: la del cwd; si el cwd es la carpeta del issue (varios repos), la del
# primer repo que tenga.
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
repos=()
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  repos=("$cwd")
else
  for d in "$cwd"/*/; do
    [ -e "$d.git" ] && repos+=("${d%/}")
  done
  [ ${#repos[@]} -gt 0 ] && branch=$(git -C "${repos[0]}" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Issue: de la rama (feat/issue-42-x), del nombre de la sesión (issue-42) o de
# la carpeta (worktrees/issue-42), en ese orden (docs/03 §6).
sess_name=$(json_get session_title)
issue=
if [[ $branch =~ (^|/)issue-([0-9]+)(-|$) ]]; then
  issue=${BASH_REMATCH[2]}
elif [[ $sess_name =~ ^issue-([0-9]+)$ ]]; then
  issue=${BASH_REMATCH[1]}
elif [[ $cwd =~ /worktrees/issue-([0-9]+)(/|$) ]]; then
  issue=${BASH_REMATCH[1]}
fi

# Carpeta relativa a la raíz del workspace (docs/01): la que tiene docs/workspace/.
rel=$cwd
if root=$(find_up docs/workspace "$cwd"); then
  rel=${cwd#"$root"}
  rel=${rel#/}
  [ -n "$rel" ] || rel=.
fi

summary=
pending=
case $evento in
  espera) summary=$(json_get message) ;;
  reposo) summary=$(json_get last_assistant_message) ;;
  fin)
    unpushed=()
    uncommitted=()
    for r in "${repos[@]}"; do
      name=$(basename "$r")
      n=$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      [ "${n:-0}" -gt 0 ] && uncommitted+=("$name ($n)")
      # Ramas locales sin upstream o con commits que el remoto no tiene.
      while IFS=' ' read -r b up ahead; do
        [ -n "$b" ] || continue
        if [ -z "$up" ] || [ "${ahead:-0}" -gt 0 ]; then unpushed+=("$name $b"); fi
      done < <(git -C "$r" for-each-ref refs/heads --format='%(refname:short) %(upstream:short) %(upstream:track,nobracket)' 2>/dev/null |
        sed -E 's/ ahead ([0-9]+).*/ \1/; s/ (behind|gone)[^ ]*.*$/ 0/')
    done
    pending="{\"unpushed\":$(json_array "${unpushed[@]+"${unpushed[@]}"}"),\"uncommitted\":$(json_array "${uncommitted[@]+"${uncommitted[@]}"}")}"
    ;;
esac
summary=$(printf '%s' "$summary" | tr '\r\n\t' '   ')
summary=${summary:0:500}

args="{\"session_id\":$(json_str "$session_id"),\"state\":\"$state\",\"at\":\"$(now_utc)\",\"tool\":\"claude-code\""
[ -n "$sess_name" ] && args+=",\"name\":$(json_str "$sess_name")"
args+=",\"host\":$(json_str "$(hostname 2>/dev/null)"),\"cwd\":$(json_str "$rel")"
[ -n "$branch" ] && [ "$branch" != HEAD ] && args+=",\"branch\":$(json_str "$branch")"
[ -n "$issue" ] && args+=",\"issue\":$(json_str "$issue")"
[ -n "$summary" ] && args+=",\"summary\":$(json_str "$summary")"
[ -n "$pending" ] && args+=",\"pending\":$pending"
args+="}"

mcp_report_status "$args"
exit 0
