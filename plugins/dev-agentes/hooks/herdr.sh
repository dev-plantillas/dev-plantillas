#!/usr/bin/env bash
# Barra lateral de herdr (docs/03 §13). Sólo dentro de herdr (HERDR_ENV=1).
#
#   herdr.sh inicio   SessionStart      etiquetas de estado en español + limpia la marca de espera
#   herdr.sh turno    UserPromptSubmit  limpia la marca de espera (la sesión volvió a recibir trabajo)
#
# La marca de espera la pone la sesión con el skill `esperando` (tokens de la
# fuente dev-espera: espera, espera_tipo, espera_a). Nunca bloquea ni escribe en
# stdout. Desactivar: DEV_AGENTES_NO_HERDR=1.
set -uo pipefail

[ "${DEV_AGENTES_NO_HERDR:-}" = 1 ] && exit 0
[ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_PANE_ID:-}" ] || exit 0
herdr=${HERDR_BIN_PATH:-herdr}
command -v "$herdr" >/dev/null 2>&1 || exit 0
cat >/dev/null # el JSON del evento no hace falta

if [ "${1:-}" = inicio ]; then
  "$herdr" pane report-metadata "$HERDR_PANE_ID" --source dev-estados \
    --state-label "blocked=⚠ TU DECISIÓN" \
    --state-label "working=trabajando" \
    --state-label "done=✓ terminó" \
    --state-label "idle=libre" \
    --state-label "unknown=?" >/dev/null 2>&1
fi
"$herdr" pane report-metadata "$HERDR_PANE_ID" --source dev-espera \
  --clear-token espera --clear-token espera_tipo --clear-token espera_a >/dev/null 2>&1
exit 0
