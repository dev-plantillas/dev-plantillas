# dev-agentes

Plugin de Claude Code con el flujo de trabajo de `dev-plantillas`: pocas piezas,
cada una basada en un paso real del trabajo, no un catálogo genérico.

## Instalar

```
/plugin marketplace add dev-plantillas/dev-plantillas
/plugin install dev-agentes@dev-plantillas
```

Para probar cambios locales sin instalar: `claude --plugin-dir ./plugins/dev-agentes`.

## Contenido

| Tipo | Nombre | Qué hace |
|---|---|---|
| Skill | `/verificar` | Build, tests, lint y formato de cada proyecto tocado (Go, Node/Angular, Python); deja la evidencia en el issue |
| Hook | `guard-worktree` | Si la sesión trabaja en `worktrees/issue-<n>/`, bloquea ediciones a otros archivos del workspace (copias principales, otros issues). Permite la carpeta de su issue en el repo de documentación (`docs/contenido/issues/<n>-*/`, con o sin ceros a la izquierda; ver `docs/06-documentacion.md`), el formato anterior `docs/issues/<n>-*.md` y todo lo que esté fuera del workspace. Nunca otros issues ni `_generado/` |
| Hook | `format` | Después de cada edición: `gofmt`, `prettier` del proyecto o `ruff format`. Nunca bloquea |
| Hooks | `estado` | Reportan al tracker el estado de la sesión (`docs/03` §4 y §7) con `report_status` de su servidor MCP: `en-reposo` al abrir, `trabajando` en cada turno (y un latido por minuto mientras trabaja), `esperando-ok` cuando pide permiso o pregunta, `en-reposo` con el resumen del turno al terminarlo y `terminada` al cerrar, con las ramas sin push y los cambios sin commit que quedaron. Sólo si hay tracker configurado |

### Estado en el tracker

Los hooks de estado usan las mismas variables que el `.mcp.json` de la base
común (`docs/15` §4), definidas en el entorno de cada persona:

| Variable | Contenido |
|---|---|
| `TRACKER_MCP_URL` | URL del servidor MCP del tracker (`https://<tracker>/mcp`) |
| `TRACKER_TOKEN` | Token de la persona (`Authorization: Bearer`) |

Sin las dos, no hacen nada. Nunca bloquean ni agregan nada al contexto: el
trabajo corre en segundo plano, con `curl` y un tope de 5 s por request
(`DEV_AGENTES_TIMEOUT`). Lo que falla queda en
`~/.claude/dev-agentes/estado.log` (`DEV_AGENTES_LOG`). El issue sale de la
rama (`feat/issue-42-x`), del nombre de la sesión (`issue-42`) o de la carpeta
(`worktrees/issue-42`), y la carpeta se informa relativa a la raíz del
workspace (la que tiene `docs/workspace/`).

### Variables para desactivar

| Variable | Efecto |
|---|---|
| `DEV_AGENTES_ALLOW_OUTSIDE=1` | Desactiva `guard-worktree` (editar fuera del issue a conciencia) |
| `DEV_AGENTES_NO_FORMAT=1` | Desactiva `format` |
| `DEV_AGENTES_NO_ESTADO=1` | Desactiva los hooks de estado |

Próximas piezas (ver `docs/03-flujo-de-trabajo.md`): revisores por stack (`go-reviewer`, `angular-reviewer`,
`migration-reviewer`), `/issue-start`, `/cerrar-issue`, `/nuevo-proyecto`.

## Diseño

- **Lo determinístico va en scripts**, no en el prompt. `/verificar` delega en
  `skills/verificar/scripts/verify.sh`, que se puede correr y testear sin agente:
  ```bash
  bash plugins/dev-agentes/skills/verificar/scripts/verify.sh [rutas...]
  ```
- **Costo de contexto bajo**: cada skill paga sólo su descripción (~150 tokens)
  en cada sesión; el cuerpo se carga al invocarla. Revisar con
  `claude --plugin-dir ./plugins/dev-agentes plugin details dev-agentes`.
- **Validación** en CI: `claude plugin validate --strict` y los tests de hooks
  (`bash plugins/dev-agentes/tests/hooks.test.sh`), que simulan el JSON que
  manda Claude Code, incluidas rutas de Windows. Los de estado usan un `curl`
  falso (`tests/fake-curl/`) que responde como un servidor MCP con sesión.
- Los hooks son `bash` (en Windows, Claude Code los corre con Git Bash) y leen
  JSON con `jq`, `node` o `python`, lo que haya.
