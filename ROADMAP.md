# Hoja de ruta

Estado de `dev-plantillas` y qué sigue, en orden de prioridad. Cada pieza tiene
su especificación en `docs/`; acá sólo el estado y el orden.

Leyenda: ✅ publicada · 🔨 en construcción · 📐 especificada · 💭 idea

## Estado actual

### Plantillas

| Plantilla | Estado | Versión | Spec |
|---|---|---|---|
| `go-grpc-service` | ✅ | v0.4.0 | `docs/04` |
| `protos` | ✅ | v0.4.0 | — |
| `api-gateway` (fase 1) | ✅ | v0.3.0 | `docs/05` |
| `angular-app` | ✅ | v0.5.0 | `docs/07` |
| `docs` | ✅ | v0.5.0 | `docs/06` |
| `astro-site` | ✅ | v0.4.0 | `docs/07` |
| `android-app` | ✅ | v0.3.0 | `docs/09` |
| `e2e-tests` | ✅ | v0.3.0 | `docs/12` |
| `api-gateway` con MCP (`mcp: true`) | ✅ | v0.3.0 | `docs/15`, `docs/05` |
| `observabilidad-stack` | 📐 | — | `docs/14` |
| `react-app` | 📐 | — | `docs/07`, `docs/13` |
| `python-grpc-service` | 💭 | — | `docs/13` |
| `ts-grpc-service` | 💭 | — | `docs/13` |

### Herramientas y capas comunes

| Pieza | Estado | Spec |
|---|---|---|
| Plugin `dev-agentes`: `/verificar`, hooks `guard-worktree` y `format` | ✅ | `plugins/dev-agentes` |
| Plugin `dev-agentes`: hooks de estado del agente (`report_status` al tracker) | ✅ 0.2.0 | `docs/03` §6–§7 |
| Plugin `dev-agentes` v2: `/issue-start`, `/cerrar-issue`, `/coordinar` | 📐 | `docs/03` |
| Plugin `dev-agentes`: sesiones en herdr (`/nueva-sesion`, `/esperando`, hook `herdr`) y layout de repo único | ✅ 0.3.0 | `docs/03` §13, `docs/01` |
| Gestión de agentes: actores, estados, protocolo con el tracker | 📐 | `docs/03` |
| `AGENTS.md` como fuente (plantillas y `docs/workspace/`) y `CLAUDE.md` con `@AGENTS.md` desde `_base` | ✅ | `docs/03` §8 |
| Capas de plataforma y `bootstrap` (`.ps1` y `.sh`) en la plantilla `docs`, rutas relativas a la raíz | ✅ | `docs/01` |
| MCP: servidores aprobados, `.mcp.json` y permisos en `_base` | ✅ | `docs/15` §4 |
| Destinos de deploy Google / Coolify y migración entre ellos | ✅ | `docs/04` |
| Base común de repos, fase 1 (`templates/_base`: gitleaks, `.gitignore` de secretos, `SECURITY.md`, `CODEOWNERS`, plantilla de MR/PR, título del MR/PR) | ✅ | `docs/10` §11 |
| Base común de repos, fases 2–5 (manifiesto, Renovate, release-please, protección) | 📐 | `docs/10` |
| Repo `ci` de pipelines reutilizables | 📐 | `docs/11` |
| Pruebas en el flujo (estándar) | 📐 | `docs/12` |
| Observabilidad | 📐 | `docs/14` |
| CLI `dp` | 🔨 H1 (en pair) | `docs/08` |

## Próximo (en este orden)

1. **Cerrar MCP y gestión de agentes, fase 1:** lo de `dev-plantillas` está
   publicado (2026-11-09). Falta que Tekitla (`tekitla-mcp`) use `mcp: true` e
   implemente `report_status` con los argumentos de `docs/03` §6, y que su MCP
   lo consuma una sesión de Claude Code y una de Codex. Después: `x-agent-id`
   para auditar el agente. — `docs/15` §10
2. **CLI `dp` H1–H2** (`list` y `new`): a partir de acá `dp` reemplaza los
   comandos largos de Copier. — `docs/08` §9
3. **Observabilidad, fase 1:** trazas + logs correlacionados en `go-grpc-service`
   y `api-gateway`; `observabilidad-stack` mínimo. — `docs/14` §11
4. **Recorrido de punta a punta:** un proyecto demo construido con todas las
   plantillas y desplegado en Coolify; documenta y prueba que todo encaja.

## Después

| Pieza | Spec |
|---|---|
| Base común fases 2–5: manifiesto `.dp/repo.yaml` + `sincronizar` en docs, Renovate, release-please, `dp repo proteger` | `docs/10` |
| Repo `ci` y migración de las plantillas a CI compartido (`ci_modo`) | `docs/11` |
| CLI `dp` H3–H11: `doctor`, catálogo remoto, workspace, issues, `update --all`, `--remoto`, mantenimiento de plantillas, skills sobre `dp --json`, `dp agentes` | `docs/08` |
| Gateway fase 2 (`protovalidate`, circuit breaker), fase 3 (Redis), fase 4 (GraphQL) | `docs/05` |
| Observabilidad fases 2–4: métricas RED, SLOs y alertas, destino Google, front y móvil | `docs/14` |
| `e2e-tests` disparada desde los deploys a QA (requiere `ci`) | `docs/12` |
| Plugin: `/issue-start`, `/cerrar-issue`, `/nuevo-proyecto`; revisores `go-reviewer` (ejercicio), `android-reviewer`, `front-reviewer`, `migration-reviewer` | `docs/03`, `docs/09` |

## Más adelante (cuando un proyecto lo pida)

- `react-app`, `python-grpc-service`, `ts-grpc-service`.
- Kotlin Multiplatform para sumar iOS a `android-app`.
- Adaptador SOAP (Java) para el gateway.
- Plantilla de Supabase (alternativa documentada en `docs/04`).

## Presentación pública

- README en inglés (o bilingüe), con un GIF de `dp new`.
- Página del proyecto construida con `astro-site`.
- Releases de GitHub con notas en cada versión de plantilla.

## Cómo se actualiza este archivo

Al mergear un PR que cambia el estado de una pieza, se actualiza su fila en el
mismo PR. Lo que entra o sale de «Próximo» se decide explícitamente.
