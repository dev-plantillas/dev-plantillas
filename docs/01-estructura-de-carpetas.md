# Estructura de carpetas del equipo

Todos los integrantes clonan los repos con **la misma estructura y los mismos
nombres**. Así los `AGENTS.md` / `CLAUDE.md`, los scripts (`make workspace`,
`../protos`) y las rutas que se pasan entre sesiones funcionan en cualquier
máquina.

## Dónde vive: la raíz del workspace

El **workspace** es la carpeta que contiene `docs/`, `backend/`, `frontend/` y
`worktrees/`. Cada persona elige dónde ponerlo:

| Sistema | Raíz recomendada |
|---|---|
| Windows | `C:/dev/<org>` |
| macOS / Linux | `~/dev/<org>` |

**Todas las rutas de la documentación, de los `AGENTS.md` y de los mensajes
entre sesiones son relativas a la raíz, con `/`** (`backend/<repo>`,
`docs/contenido/issues/`, `worktrees/issue-<n>/<repo>`). Nunca rutas absolutas
de una máquina: el equipo crece y cada persona tiene otra raíz u otro sistema
operativo. La raíz se define una sola vez, en el `AGENTS.md` de plataforma.

**Nunca dentro de OneDrive, Dropbox ni iCloud.** La sincronización bloquea archivos
mientras git o los agentes escriben, corrompe `.git`, deja carpetas de sólo
lectura que git no puede borrar y sube `node_modules`, `vendor/`, `.env` y
credenciales. El respaldo del código es el remoto (GitLab/GitHub), no la nube
del sistema operativo. Los scripts de `bootstrap` se niegan a correr ahí.

## Layout

```text
<raíz>/
├── CLAUDE.md, AGENTS.md      ← reglas de toda la plataforma (generados; ver abajo)
├── docs/                     ← repo de documentación (plantilla docs): issues en
│                               contenido/issues/<n>-<slug>/, ADRs, runbooks y
│                               workspace/ (capas de plataforma y bootstrap)
├── backend/
│   ├── CLAUDE.md, AGENTS.md  ← convenciones comunes del backend (generados)
│   ├── protos/               ← contratos (repo <org>/protos)
│   ├── api-gateway/
│   ├── <dominio>-service/    ← un repo por micro
│   └── ...
├── frontend/
│   ├── CLAUDE.md, AGENTS.md  ← convenciones comunes del front (generados)
│   └── <app>/                ← un repo por app (admin, landing, ...)
├── tools/                    ← scripts y migraciones de datos (repo propio)
└── worktrees/                ← worktrees de agentes, uno por issue (ver abajo)
    └── issue-42/
        ├── orders-service/
        └── api-gateway/
```

### Proyecto de un solo repo

Un proyecto que es un único repo (sin `docs/`, `backend/` ni `frontend/`
propios) no arma workspace: la copia principal vive en `<raíz>/<repo>` y se
queda en `main`, y los worktrees van en una **carpeta hermana con sufijo
`-wt`**, uno por issue:

```text
C:/dev/
├── <repo>/                ← copia principal, en main y limpia
└── <repo>-wt/
    ├── issue-7/           ← worktree del issue 7 (rama feat/issue-7-<slug>)
    └── issue-12/
```

La carpeta hermana, y no `<repo>/worktrees/`, para que los worktrees no queden
dentro del árbol del repo (git, los formateadores y los buscadores los verían
como archivos propios). Las reglas de abajo valen igual. `nueva-sesion.ps1`
(`docs/03` §13) detecta solo cuál de los dos layouts tiene el proyecto.

### Reglas

1. **El nombre de la carpeta es el nombre del repo.** No hay alias: si el repo es
   `protos`, la doc también lo llama `protos`.
2. **Una sola fuente de verdad por tema.** Nada de clones viejos «de referencia»
   dentro del árbol: si hace falta una versión vieja se usa `git worktree` o un tag.
3. **La copia principal de cada repo se queda en `main` y limpia.** Nadie (ni
   humano ni agente) trabaja features ahí; sirve para leer y para crear worktrees.
4. **El trabajo vive en `worktrees/issue-<n>/`.** Un issue que toca tres repos
   tiene tres worktrees bajo la misma carpeta. Al cerrar el issue se borra la
   carpeta entera (`git worktree remove`).
5. **Nada de archivos sueltos en la raíz** (PDFs, Excel, prompts). Van a `docs/`
   o a `tools/` según corresponda.

## Contexto para agentes (`AGENTS.md` y `CLAUDE.md` en capas)

Claude Code lee el `CLAUDE.md` del directorio donde arranca **y el de cada carpeta
padre**; Codex y otras herramientas hacen lo mismo con `AGENTS.md`. Se aprovecha
para no repetir reglas. En cada nivel, **`AGENTS.md` es la fuente** y `CLAUDE.md`
lo importa y agrega sólo lo propio de Claude Code (`docs/03` §8):

| Nivel | Contiene | Tamaño guía |
|---|---|---|
| `<raíz>/` | Mapa de repos, flujo de issues, nombres de ramas y commits, qué despliega, dónde está la doc | ≤ 150 líneas |
| `backend/` | Arquitectura hexagonal, errores, tests, protos, deploy | ≤ 200 líneas |
| `frontend/` | Stack, estructura de `src/app`, estilos, cómo pedir endpoints | ≤ 150 líneas |
| `<repo>/` | Sólo lo propio del repo: puerto, schema, dependencias, particularidades | ≤ 200 líneas |

**Dónde se versionan:** los de cada repo, en el repo (la plantilla trae su
`AGENTS.md` y la base común su `CLAUDE.md`, `docs/10` §11). Los de la raíz,
`backend/` y `frontend/` no son de ningún repo de código: viven en el **repo de
documentación**, en `docs/workspace/` (lo trae la plantilla `docs`), porque todo
el equipo ya lo clona. `docs/workspace/bootstrap` los aplica:

- En la raíz, `backend/` y `frontend/` escribe un `CLAUDE.md` de una línea que
  **importa** la fuente (`@docs/workspace/CLAUDE.md`,
  `@../docs/workspace/backend/AGENTS.md`): un `git pull` de `docs` alcanza para
  que Claude Code vea el cambio.
- Escribe al lado un `AGENTS.md` que es una **copia** con el aviso «generado, no
  editar», para las herramientas que no siguen imports (Codex). Se refresca
  corriendo `bootstrap` de nuevo.
- Los archivos de la raíz no se editan a mano: se cambian en `docs/workspace/`
  con un MR/PR.

Lo que **no** va en un `AGENTS.md` ni en un `CLAUDE.md`: historial de incidentes, decisiones con su
contexto (→ ADR en `docs/`), changelogs, notas de un issue (→ el issue).

## Arranque de una máquina nueva

Se clona el repo de documentación en `<raíz>/docs` y se corre su `bootstrap`,
que crea las carpetas, clona los repos de `docs/workspace/repos.txt` y genera
los archivos de contexto. Es idempotente.

```powershell
# Windows
git clone <url>/docs.git C:\dev\<org>\docs
C:\dev\<org>\docs\workspace\bootstrap.ps1
```

```bash
# macOS / Linux (o Git Bash)
git clone <url>/docs.git ~/dev/<org>/docs
bash ~/dev/<org>/docs/workspace/bootstrap.sh
```

**Workspace armado con la versión anterior** (capas copiadas desde
`dev-plantillas/workspace/` con `scripts/bootstrap.ps1`): pasar el contenido
propio de los `CLAUDE.md` de la raíz, `backend/` y `frontend/` a
`docs/workspace/` (con un MR/PR) y correr `bootstrap`, que los reemplaza.
