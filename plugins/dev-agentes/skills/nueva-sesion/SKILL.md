---
name: nueva-sesion
description: Abre otra sesión de Claude Code para un issue dentro de herdr (worktrees del estándar + workspace + sesión con nombre + primer mensaje), y la cierra cuando terminó. Usar cuando una sesión coordinadora necesita delegar un issue a una sesión nueva, cuando el usuario pide "abrí una sesión para el issue N", o para cerrar una sesión de issue que ya terminó.
---

# Abrir y cerrar sesiones de issue en herdr

Reglas completas en `docs/03` §13 de dev-plantillas. Necesita correr dentro de
herdr (`HERDR_ENV=1`); si no, preparás sólo los worktrees y le decís a la
persona que abra la sesión a mano.

## Abrir

```powershell
& "<directorio de esta skill>/scripts/nueva-sesion.ps1" `
  -Base <raíz del proyecto> -Issue <n> -Slug <kebab-case> `
  [-Repos backend\api-gateway,docs] [-Type feat|fix|chore|docs] `
  -Herdr [-Prompt "<primer mensaje>"] [-Focus]
```

- **Workspace de varios repos** (la raíz tiene `worktrees/`): `-Repos` es
  obligatorio; crea `worktrees/issue-<n>/<repo>` (el repo `docs` con rama `docs/...`).
- **Repo único**: crea `<raíz>-wt/issue-<n>` (`docs/01`).
- Reutiliza los worktrees que ya existen. Rama `<Type>/issue-<n>-<Slug>` desde `origin/main`.
- Abre el workspace `<proyecto> #<n>`, arranca `claude -n issue-<n>` y el
  agente de herdr se llama `<proyecto>-issue-<n>`. Devuelve un JSON con `cwd`,
  `pane` y `agente`.

Antes de abrir:

- **El issue tiene que existir** (en `docs/contenido/issues/` o en el tracker).
  El primer mensaje dice qué issue trabajar, qué queda fuera de alcance y qué
  no puede hacer sin la persona (prod, merges, tags `prod-v*`, secretos).
- **No más de 3 sesiones abiertas por vos a la vez** sin que la persona lo pida:
  cada una gasta.
- Si Claude pregunta si confía en la carpeta, el script espera: **no la
  aceptes vos**; avisale a la persona que la acepte en ese workspace.

Para seguirla: `herdr agent get <agente>`, `herdr agent wait <agente> --until idle`,
`herdr agent read <agente> --source recent --lines 40`. Para hablarle, mejor un
mensaje entre sesiones a `issue-<n>`; `herdr agent prompt` sólo si no responde.

## Cerrar

Quien abre una sesión la cierra, **siempre con el script** (nunca
`herdr workspace close` directo):

```powershell
& "<directorio de esta skill>/scripts/cerrar-sesion.ps1" -Agente <proyecto>-issue-<n>              # sólo revisa
& "<directorio de esta skill>/scripts/cerrar-sesion.ps1" -Agente <proyecto>-issue-<n> -Confirmar   # revisa y cierra
```

Cierra sólo si el workspace es de issue y no es el tuyo, Claude está `idle` o
`done`, no tiene marca de espera, ningún worktree tiene cambios sin commit ni
commits sin push, y ningún proceso de la sesión escucha un puerto. Si algo
falla, lo lista y no cierra: resolvelo con esa sesión o avisale a la persona.

- Sólo cerrás las sesiones **que abriste vos**. Las principales (las que no son
  `<proyecto> #<n>`) las cierra la persona; el script las rechaza.
- Una sesión con marca de espera (por ejemplo, espera un merge) no se cierra: su
  trabajo sigue vivo.
- Los worktrees se borran aparte, cuando el MR/PR está mergeado
  (`git -C <repo> worktree remove <ruta>`).
