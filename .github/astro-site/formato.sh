#!/usr/bin/env bash
# Genera astro-site en todas las combinaciones válidas de idiomas, blog,
# entidades_api, render, analytics y deploy_target (84; el CI rota) y corre
# `prettier --check` en cada una. Reglas de copier.yml: hibrido necesita
# entidades_api; cloud-run necesita hibrido.
# Atrapa el espaciado que deja un {% if %} de Jinja en una combinación que la
# matriz completa no genera. Sólo instala prettier: no necesita @vrojas1015/vrb.
#   bash .github/astro-site/formato.sh <dir-de-trabajo>
set -uo pipefail
plantilla="$(cd "$(dirname "$0")/../../templates/astro-site" && pwd)"
tmp=${1:?uso: formato.sh <dir-de-trabajo>}
mkdir -p "$tmp"

# Las mismas versiones de prettier y del plugin que el proyecto generado.
copier copy --defaults --trust "$plantilla" "$tmp/base" >/dev/null
version() { grep -oE "\"$1\": \"[^\"]+\"" "$tmp/base/package.json" | cut -d'"' -f4; }
mkdir -p "$tmp/prettier" && echo '{"private":true}' >"$tmp/prettier/package.json"
npm install --prefix "$tmp/prettier" --no-audit --no-fund --loglevel=error \
  "prettier@$(version prettier)" "prettier-plugin-astro@$(version prettier-plugin-astro)"

cis=(github gitlab)
i=0 malos=0
for idiomas in "[es]" "[es, en]"; do
  for blog in true false; do
    for ent in true false; do
      for render in estatico hibrido; do
        [ "$render" = hibrido ] && [ "$ent" = false ] && continue
        deploys="firebase-hosting coolify"
        [ "$render" = hibrido ] && deploys="$deploys cloud-run"
        for analytics in ninguna plausible ga4; do
          for deploy in $deploys; do
            ci=${cis[$((i % 2))]}
            i=$((i + 1))
            combo="idiomas=$idiomas blog=$blog entidades_api=$ent render=$render analytics=$analytics deploy_target=$deploy ci_provider=$ci"
            d="$tmp/c$i"
            if ! copier copy --defaults --trust -d "idiomas=$idiomas" -d blog=$blog -d entidades_api=$ent \
              -d render=$render -d analytics=$analytics -d deploy_target=$deploy -d ci_provider=$ci \
              "$plantilla" "$d" >/dev/null 2>&1; then
              echo "::error::copier falló con $combo"
              malos=$((malos + 1))
              continue
            fi
            ln -s "$tmp/prettier/node_modules" "$d/node_modules"
            if ! (cd "$d" && "$tmp/prettier/node_modules/.bin/prettier" --check . >"$d.log" 2>&1); then
              echo "::error::prettier --check falla con $combo"
              grep -i warn "$d.log" | grep -v 'Code style'
              malos=$((malos + 1))
            fi
            rm -rf "$d"
          done
        done
      done
    done
  done
done
echo "$i combinaciones, $malos con problemas"
[ "$malos" = 0 ]
