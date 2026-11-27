#!/usr/bin/env bash
# Tests de los hooks: arman el JSON que manda Claude Code y comprueban el exit.
#   bash plugins/dev-agentes/tests/hooks.test.sh
set -uo pipefail
HOOKS="$(cd "$(dirname "$0")/../hooks" && pwd)"
pass=0; fail=0

check() { # descripción exit-esperado json [env]
  local desc=$1 want=$2 json=$3 got
  printf '%s' "$json" | env ${4:-} bash "$HOOKS/guard-worktree.sh" >/dev/null 2>&1; got=$?
  if [ "$got" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $desc (exit $got, esperado $want)"; fi
}
# Arma el evento escapando las \ como en un JSON real.
esc() { local s=$1; s=${s//'\'/'\\'}; printf '%s' "$s"; }
ev() { printf '{"cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$(esc "$1")" "$(esc "$2")"; }

W=/home/dev/org
I=$W/worktrees/issue-42
check "dentro del worktree"             0 "$(ev "$I" "$I/orders-service/app/x.go")"
check "ruta relativa dentro"            0 "$(ev "$I/orders-service" "app/x.go")"
check "copia principal del repo"        2 "$(ev "$I" "$W/backend/orders-service/app/x.go")"
check "worktree de otro issue"          2 "$(ev "$I" "$W/worktrees/issue-7/foo/x.go")"
check "prefijo engañoso issue-420"      2 "$(ev "$I" "$W/worktrees/issue-420/x.go")"
check "su propio issue en docs"         0 "$(ev "$I" "$W/docs/issues/42-descuentos.md")"
check "issue con ceros a la izquierda"  0 "$(ev "$I" "$W/docs/issues/042-descuentos.md")"
check "otro issue en docs"              2 "$(ev "$I" "$W/docs/issues/43-otro.md")"
check "archivo agregado de docs"        2 "$(ev "$I" "$W/docs/rollout.md")"
# Repo docs con carpeta por issue (plantilla docs): contenido/issues/<n>-<slug>/
D=$W/docs/contenido
check "carpeta: su issue.md"            0 "$(ev "$I" "$D/issues/042-descuentos/issue.md")"
check "carpeta: su plan.md sin ceros"   0 "$(ev "$I" "$D/issues/42-descuentos/plan.md")"
check "carpeta: subcarpeta propia"      0 "$(ev "$I" "$D/issues/042-descuentos/evidencia/log.txt")"
check "carpeta: issue 43"               2 "$(ev "$I" "$D/issues/043-otro/issue.md")"
check "carpeta: 0420 no es 42"          2 "$(ev "$I" "$D/issues/0420-otro/issue.md")"
check "carpeta: la carpeta sola"        2 "$(ev "$I" "$D/issues/042-descuentos")"
check "carpeta: archivo suelto"         2 "$(ev "$I" "$D/issues/042-descuentos.md")"
check "carpeta: escapar con .."         2 "$(ev "$I" "$D/issues/042-descuentos/../043-otro/issue.md")"
check "carpeta: _generado"              2 "$(ev "$I" "$D/_generado/issues-por-estado.md")"
check "carpeta: adr"                    2 "$(ev "$I" "$D/adr/0001-registrar-decisiones.md")"
check "carpeta: _plantillas"            2 "$(ev "$I" "$W/docs/_plantillas/issue.md")"
I420=$W/worktrees/issue-420
check "carpeta: issue-420 vs 042"       2 "$(ev "$I420" "$D/issues/042-descuentos/issue.md")"
check "carpeta: issue-420 su carpeta"   0 "$(ev "$I420" "$D/issues/420-grande/issue.md")"
check "fuera del workspace"             0 "$(ev "$I" "/tmp/scratch/notas.md")"
check "sesión fuera de worktree"        0 "$(ev "$W/backend/orders-service" "$W/backend/orders-service/x.go")"
check "sin file_path"                   0 '{"cwd":"'"$I"'","tool_name":"Edit","tool_input":{}}'
check "escape con variable"             0 "$(ev "$I" "$W/backend/orders-service/x.go")" DEV_AGENTES_ALLOW_OUTSIDE=1

# Rutas Windows y mayúsculas distintas
WW='C:\dev\org'
check "win: dentro"                     0 "$(ev "$WW\worktrees\issue-42" "$WW\worktrees\issue-42\api\x.go")"
check "win: copia principal"            2 "$(ev "$WW\worktrees\issue-42" "$WW\backend\api\x.go")"
check "win: mezcla / y \ y mayúsculas"  0 "$(ev "c:/dev/org/worktrees/issue-42" 'C:\Dev\Org\worktrees\issue-42\api\x.go')"
check "win: estilo /c/ de git bash"     2 "$(ev "/c/dev/org/worktrees/issue-42" "$WW\backend\api\x.go")"
check "win: otro issue en docs"         2 "$(ev "$WW\worktrees\issue-42" "$WW\docs\issues\43-x.md")"
check "win: su issue en docs"           0 "$(ev "$WW\worktrees\issue-42" "$WW\docs\issues\42-x.md")"
check "win: su carpeta de issue"        0 "$(ev "$WW\worktrees\issue-42" "$WW\docs\contenido\issues\042-x\issue.md")"
check "win: carpeta mayúsculas"         0 "$(ev "$WW\worktrees\issue-42" 'C:\Dev\Org\Docs\Contenido\Issues\042-X\plan.md')"
check "win: carpeta de otro issue"      2 "$(ev "$WW\worktrees\issue-42" "$WW\docs\contenido\issues\043-x\issue.md")"
check "win: _generado"                  2 "$(ev "$WW\worktrees\issue-42" "$WW\docs\contenido\_generado\adr.md")"
check "win: git bash /c/ carpeta"       0 "$(ev "/c/dev/org/worktrees/issue-42" "/c/dev/org/docs/contenido/issues/042-x/issue.md")"

# format.sh nunca bloquea, aunque el archivo no exista o no compile
tmp=$(mktemp -d); printf 'package x\nvar   A = 1\n' > "$tmp/a.go"; printf 'package x\nfunc (\n' > "$tmp/b.go"
for f in "$tmp/a.go" "$tmp/b.go" "$tmp/no-existe.go"; do
  printf '{"tool_input":{"file_path":"%s"}}' "$f" | bash "$HOOKS/format.sh"; rc=$?
  if [ $rc = 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: format.sh exit $rc con $f"; fi
done
if command -v gofmt >/dev/null; then
  if grep -q '^var A = 1$' "$tmp/a.go"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: gofmt no formateó a.go"; fi
fi
rm -rf "$tmp"

# --- estado.sh: reportes al tracker (curl falso, sin red) --------------------
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); echo "FAIL: estado: $1"; }
FAKE="$(cd "$(dirname "$0")/fake-curl" && pwd)"
chmod +x "$FAKE/curl" 2>/dev/null
ws=$(mktemp -d)
export FAKE_CURL_LOG="$ws/curl.log" DEV_AGENTES_LOG="$ws/estado.log" DEV_AGENTES_ESTADO_SYNC=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$ws/docs/workspace" "$ws/worktrees/issue-42"
repo="$ws/worktrees/issue-42/orders-service"
git init -q -b feat/issue-42-descuentos "$repo" && git -C "$repo" commit -q --allow-empty -m init

# estado <evento> <json> [VAR=valor...]: corre el hook con el tracker configurado.
estado() {
  local ev=$1 json=$2; shift 2
  : >"$FAKE_CURL_LOG"
  printf '%s' "$json" | env PATH="$FAKE:$PATH" TRACKER_MCP_URL=https://tracker.test/mcp TRACKER_TOKEN=tok "$@" \
    bash "$HOOKS/estado.sh" "$ev" >"$ws/stdout" 2>&1
}
# Cuerpo del tools/call (última línea del log) y su validez como JSON.
reporte() { tail -1 "$FAKE_CURL_LOG" | cut -d'|' -f3-; }
json_ok() {
  local py; for py in python3 python; do "$py" -c 1 >/dev/null 2>&1 && break || py=; done
  [ -z "$py" ] && return 0
  reporte | "$py" -c 'import json,sys; json.load(sys.stdin)'
}
sev() { printf '{"session_id":"s1","cwd":"%s"%s}' "$(esc "$1")" "${2:-}"; }
I42="$ws/worktrees/issue-42"

estado turno "$(sev "$I42")" DEV_AGENTES_NO_ESTADO=1
[ ! -s "$FAKE_CURL_LOG" ] && ok || ko "DEV_AGENTES_NO_ESTADO=1 reportó igual"
: >"$FAKE_CURL_LOG"
printf '%s' "$(sev "$I42")" | env -u TRACKER_MCP_URL PATH="$FAKE:$PATH" bash "$HOOKS/estado.sh" turno >"$ws/stdout" 2>&1; rc=$?
[ $rc = 0 ] && [ ! -s "$FAKE_CURL_LOG" ] && ok || ko "sin TRACKER_MCP_URL tenía que salir sin reportar"

estado turno "$(sev "$I42" ',"session_title":"issue-42"')"; rc=$?
r=$(reporte)
[ $rc = 0 ] && ok || ko "turno: exit $rc"
[ ! -s "$ws/stdout" ] && ok || ko "turno escribió en stdout (entra al contexto)"
[ "$(wc -l <"$FAKE_CURL_LOG" | tr -d ' ')" = 3 ] && ok || ko "turno: se esperaban initialize, initialized y tools/call"
[[ $r == *'"name":"report_status"'* && $r == *'"state":"trabajando"'* ]] && ok || ko "turno: $r"
[[ $r == *'"issue":"42"'* && $r == *'"branch":"feat/issue-42-descuentos"'* ]] && ok || ko "turno: issue/rama: $r"
[[ $r == *'"cwd":"worktrees/issue-42"'* && $r == *'"name":"issue-42"'* && $r == *'"tool":"claude-code"'* ]] && ok || ko "turno: cwd/nombre: $r"
[[ $r =~ \"at\":\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z\" ]] && ok || ko "turno: at: $r"
[[ $(tail -1 "$FAKE_CURL_LOG") == 's-123|Bearer tok|'* ]] && ok || ko "turno: sin Mcp-Session-Id o token en tools/call"
json_ok && ok || ko "turno: JSON inválido: $r"

estado inicio "$(sev "$I42")"
[[ $(reporte) == *'"state":"en-reposo"'* ]] && ok || ko "inicio: $(reporte)"

estado espera "$(sev "$I42" ',"notification_type":"permission_prompt","message":"Claude needs your permission to use Bash"')"
[[ $(reporte) == *'"state":"esperando-ok"'*'"summary":"Claude needs your permission to use Bash"'* ]] && ok || ko "espera: $(reporte)"

estado reposo "$(sev "$I42" ',"last_assistant_message":"Listo: \"tests\" en verde\nlínea 2\\\\ruta"')"
[[ $(reporte) == *'"state":"en-reposo"'*'"summary":"Listo: \"tests\" en verde línea 2\\ruta"'* ]] && ok || ko "reposo: $(reporte)"
json_ok && ok || ko "reposo: JSON inválido: $(reporte)"

# Issue por nombre de sesión, fuera de un worktree de issue y sin rama de issue.
estado turno "$(sev "$ws/docs" ',"session_title":"issue-7"')"
[[ $(reporte) == *'"issue":"7"'* && $(reporte) == *'"cwd":"docs"'* ]] && ok || ko "issue por nombre de sesión: $(reporte)"

# Latido: como mucho uno por minuto por sesión.
rm -f "${TMPDIR:-/tmp}/dev-agentes-latido-lat1"
estado latido '{"session_id":"lat1","cwd":"'"$(esc "$I42")"'"}'
n1=$(wc -l <"$FAKE_CURL_LOG" | tr -d ' ')
estado latido '{"session_id":"lat1","cwd":"'"$(esc "$I42")"'"}'
n2=$(wc -l <"$FAKE_CURL_LOG" | tr -d ' ')
[ "$n1" = 3 ] && [ "$n2" = 0 ] && ok || ko "latido: primero $n1 requests, segundo $n2 (esperado 3 y 0)"
rm -f "${TMPDIR:-/tmp}/dev-agentes-latido-lat1"

# Fin: cambios sin commit y rama sin push.
echo x >"$repo/nuevo.txt"
git -C "$repo" branch otra-local
estado fin "$(sev "$I42" ',"reason":"prompt_input_exit"')"
r=$(reporte)
[[ $r == *'"state":"terminada"'* && $r == *'"uncommitted":["orders-service (1)"]'* ]] && ok || ko "fin: sin commit: $r"
[[ $r == *'"orders-service feat/issue-42-descuentos"'* && $r == *'"orders-service otra-local"'* ]] && ok || ko "fin: sin push: $r"
json_ok && ok || ko "fin: JSON inválido: $r"

# Tracker caído: no bloquea y queda en el log.
: >"$DEV_AGENTES_LOG"
estado turno "$(sev "$I42")" FAKE_CURL_STATUS=500; rc=$?
[ $rc = 0 ] && grep -q 'HTTP 500' "$DEV_AGENTES_LOG" && ok || ko "tracker caído: exit $rc, log: $(cat "$DEV_AGENTES_LOG")"

# En segundo plano (como en una sesión real): vuelve enseguida y reporta igual.
: >"$FAKE_CURL_LOG"
printf '%s' "$(sev "$I42")" | env PATH="$FAKE:$PATH" TRACKER_MCP_URL=https://tracker.test/mcp TRACKER_TOKEN=tok DEV_AGENTES_ESTADO_SYNC= \
  bash "$HOOKS/estado.sh" turno >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do [ "$(wc -l <"$FAKE_CURL_LOG" | tr -d ' ')" = 3 ] && break; sleep 0.3; done
[ "$(wc -l <"$FAKE_CURL_LOG" | tr -d ' ')" = 3 ] && ok || ko "segundo plano: no llegó el reporte"
rm -rf "$ws"

# --- herdr.sh: barra lateral de herdr (herdr falso) ---------------------------
FH="$(cd "$(dirname "$0")/fake-herdr" && pwd)"
chmod +x "$FH/herdr" 2>/dev/null
export FAKE_HERDR_LOG; FAKE_HERDR_LOG=$(mktemp)
herdr_hook() { # evento [VAR=valor...]
  local ev=$1; shift
  : >"$FAKE_HERDR_LOG"
  echo "{}" | env -u HERDR_BIN_PATH PATH="$FH:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1:p2 "$@" bash "$HOOKS/herdr.sh" "$ev" >"$FAKE_HERDR_LOG.out" 2>&1
}
herdr_hook inicio; rc=$?
[ $rc = 0 ] && [ ! -s "$FAKE_HERDR_LOG.out" ] && ok || ko "herdr inicio: exit $rc o escribió en stdout"
grep -q -- '--source dev-estados.*--state-label blocked=⚠ TU DECISIÓN' "$FAKE_HERDR_LOG" && ok || ko "herdr inicio: sin etiquetas ($(cat "$FAKE_HERDR_LOG"))"
grep -q -- 'w1:p2 --source dev-espera --clear-token espera --clear-token espera_tipo --clear-token espera_a' "$FAKE_HERDR_LOG" && ok || ko "herdr inicio: no limpió la marca"
herdr_hook turno
[ "$(wc -l <"$FAKE_HERDR_LOG" | tr -d ' ')" = 1 ] && grep -q 'dev-espera --clear-token espera' "$FAKE_HERDR_LOG" && ok || ko "herdr turno: $(cat "$FAKE_HERDR_LOG")"
herdr_hook inicio HERDR_ENV=
[ ! -s "$FAKE_HERDR_LOG" ] && ok || ko "fuera de herdr no tiene que llamar a herdr"
herdr_hook inicio DEV_AGENTES_NO_HERDR=1
[ ! -s "$FAKE_HERDR_LOG" ] && ok || ko "DEV_AGENTES_NO_HERDR=1 llamó a herdr"
rm -f "$FAKE_HERDR_LOG" "$FAKE_HERDR_LOG.out"

echo "hooks: $pass ok, $fail fallidos"
[ $fail = 0 ]
