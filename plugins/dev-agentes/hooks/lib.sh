#!/usr/bin/env bash
# Utilidades compartidas por los hooks. Se cargan con `source`.

# Lee el JSON que Claude Code manda por stdin a la variable HOOK_INPUT.
read_input() { HOOK_INPUT=$(cat); }

# json_get <expresión con puntos>  ej: json_get tool_input.file_path
# Usa jq, node o python, lo que haya (en Windows no siempre hay jq).
json_get() {
  local path=$1
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | jq -r ".$path // empty"
  elif command -v node >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | node -e '
      let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
        let v=JSON.parse(s);for(const k of process.argv[1].split("."))v=v==null?v:v[k];
        if(v!=null)process.stdout.write(String(v));});' "$path"
  else
    local py
    for py in python python3; do
      "$py" -c 'print(1)' >/dev/null 2>&1 && break || py=
    done
    [ -n "$py" ] || return 1
    printf '%s' "$HOOK_INPUT" | "$py" -c '
import json,sys
v=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    v=v.get(k) if isinstance(v,dict) else None
if v is not None: sys.stdout.write(str(v))' "$path"
  fi
}

# Normaliza una ruta para compararla: barras /, unidad en minúscula, sin / final.
#   C:\dev\x  -> c:/dev/x     /c/dev/x -> c:/dev/x
norm_path() {
  local p=${1//\\//}
  if [[ $p =~ ^/([a-zA-Z])/(.*)$ ]]; then p="${BASH_REMATCH[1]}:/${BASH_REMATCH[2]}"; fi
  if [[ $p =~ ^([a-zA-Z]):(.*)$ ]]; then p="${BASH_REMATCH[1],,}:${BASH_REMATCH[2]}"; fi
  printf '%s' "${p%/}"
}

# Sube desde <dir> buscando un archivo; imprime el directorio que lo contiene.
find_up() { # archivo dir
  local d=$2
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    [ -e "$d/$1" ] && { printf '%s' "$d"; return 0; }
    local parent; parent=$(dirname "$d")
    [ "$parent" = "$d" ] && break
    d=$parent
  done
  return 1
}

# --- Estado (estado.sh) -------------------------------------------------------

# mtime de un archivo en segundos (GNU stat o BSD/macOS).
file_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# Fecha actual RFC 3339 en UTC, con milisegundos si `date` los da.
now_utc() {
  local t
  t=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null)
  [[ $t =~ \.[0-9]{3}Z$ ]] || t=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '%s' "$t"
}

# json_str <texto>: string JSON con comillas (escapa \ " y controles).
json_str() {
  local s=$1 out= c i
  s=${s//\/\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\n}
  s=${s//$'\r'/\r}
  s=${s//$'\t'/\t}
  # Otros controles (0x01-0x1f) se descartan.
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    [[ $c == [[:cntrl:]] ]] || out+=$c
  done
  printf '"%s"' "$out"
}

# json_array <elementos...>: lista JSON de strings.
json_array() {
  local out= x
  for x in "$@"; do out+="${out:+,}$(json_str "$x")"; done
  printf '[%s]' "$out"
}

estado_log() {
  local log=${DEV_AGENTES_LOG:-$HOME/.claude/dev-agentes/estado.log}
  mkdir -p "$(dirname "$log")" 2>/dev/null
  printf '%s %s\n' "$(now_utc)" "$*" >>"$log" 2>/dev/null || true
}

# mcp_post <json>: POST JSON-RPC al servidor MCP del tracker (HTTP streamable).
# Deja el status en MCP_STATUS, el cuerpo en MCP_BODY y la sesión (si el
# servidor la usa) en MCP_SESSION.
mcp_post() {
  local hdr body extra=()
  hdr=$(mktemp) body=$(mktemp)
  [ -n "${MCP_SESSION:-}" ] && extra=(-H "Mcp-Session-Id: $MCP_SESSION")
  MCP_STATUS=$(curl -sS --max-time "${DEV_AGENTES_TIMEOUT:-5}" -o "$body" -D "$hdr" -w '%{http_code}' \
    -X POST "$TRACKER_MCP_URL" \
    -H "Authorization: Bearer $TRACKER_TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H 'MCP-Protocol-Version: 2025-06-18' \
    "${extra[@]+"${extra[@]}"}" \
    --data-binary "$1" 2>/dev/null) || MCP_STATUS=000
  MCP_BODY=$(cat "$body" 2>/dev/null)
  local sid
  sid=$(tr -d '\r' <"$hdr" 2>/dev/null | sed -n 's/^[Mm][Cc][Pp]-[Ss][Ee][Ss][Ss][Ii][Oo][Nn]-[Ii][Dd]: *//p' | tail -1)
  [ -n "$sid" ] && MCP_SESSION=$sid
  rm -f "$hdr" "$body"
}

# mcp_report_status <argumentos JSON>: initialize + tools/call report_status.
# Nunca falla: lo que sale mal se anota en el log.
mcp_report_status() {
  MCP_SESSION=
  mcp_post '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"dev-agentes","version":"0.2.0"}}}'
  if [ "$MCP_STATUS" != 200 ]; then
    estado_log "initialize: HTTP $MCP_STATUS ${MCP_BODY:0:200}"
    return 0
  fi
  mcp_post '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  mcp_post "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"report_status\",\"arguments\":$1}}"
  if [ "$MCP_STATUS" != 200 ] || [[ $MCP_BODY == *'"isError":true'* || $MCP_BODY == *'"error":{'* ]]; then
    estado_log "report_status: HTTP $MCP_STATUS ${MCP_BODY:0:300}"
  fi
  return 0
}
