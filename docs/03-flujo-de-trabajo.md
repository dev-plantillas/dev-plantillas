# Flujo de trabajo con agentes

Una forma de trabajar para todo el equipo, pensada para varias sesiones de
agentes en paralelo (Claude Code, Codex, agentes en la nube) y personas. Cubre
la unidad de trabajo (el issue), quién trabaja (actores y sesiones), cómo se
sabe qué está haciendo cada uno (estados y tracker) y cómo se coordinan.

Las §1–§3 y §9–§10 son la forma de trabajo vigente. Las §4–§8 son
**especificación**: describen lo que suman el tracker (Tekitla) y el plugin
`dev-agentes` v2 (§12).

## 1. Unidad de trabajo: el issue

```
issue  →  worktrees  →  sesión  →  verificar  →  MR  →  cerrar
```

1. **Issue** en `docs/contenido/issues/<n>-<slug>/` (`issue.md` y, si cruza
   repos, `plan.md`): qué, por qué, criterios de aceptación, repos afectados.
   Con tracker, el issue también existe ahí y se liga con `tracker: <KEY>-<n>`
   en el frontmatter (`docs/06` §4).
2. **Worktrees**, uno por repo que toca, todos bajo `worktrees/issue-<n>/`.
   Desde la raíz del workspace (`docs/01`):
   ```bash
   git -C backend/orders-service worktree add ../../worktrees/issue-42/orders-service \
       -b feat/issue-42-descuentos origin/main
   ```
   `scripts/new-worktree.ps1` de dev-plantillas hace lo mismo para varios repos
   (y `dp issue start 42` lo reemplaza, `docs/08`).
3. **Una sesión de agente** abierta en `worktrees/issue-42/`, con nombre
   `issue-42`. La sesión ve todos los repos del issue y lee los `AGENTS.md` /
   `CLAUDE.md` de la plataforma por herencia de carpetas (§8).
4. **Plan antes de código** en cambios que cruzan repos o tocan migraciones
   (modo plan): se aprueba el orden protos → micro → gateway → front.
5. **Verificar**: `/verificar`, tests, build, `/code-review`. La evidencia se
   anota en el issue.
6. **MR por repo**, con el template. El MR de protos se mergea y se taggea primero.
7. **Cerrar**: `git worktree remove` de cada repo, borrar `worktrees/issue-<n>`
   y cerrar la sesión.

## 2. Actores

Todo trabajo lo hace un **actor**: una persona o un agente.

| Actor | Ejemplos | Particularidad |
|---|---|---|
| Persona | Integrantes del equipo | Aprueba planes y MRs, aplica cambios en prod |
| Agente local | Sesión de Claude Code o Codex en la máquina de alguien | Pertenece a la persona que lo abrió |
| Agente en la nube | Sesiones remotas, rutinas programadas, jobs de CI con agente | Pertenece a quien lo programó; no ve la máquina local |

**Todo agente pertenece a una persona.** Sus tokens se emiten a nombre de esa
persona y se revocan con ella; lo que hace un agente es responsabilidad de su
dueño.

## 3. Tipos de sesión

| Tipo | Dónde se abre | Edita | Nombre |
|---|---|---|---|
| **Issue** (por defecto) | `worktrees/issue-<n>/` | Sólo su worktree y la carpeta de su issue en `docs` | `issue-<n>` |
| **Revisión** | El worktree o el diff del MR | Nunca | `review-<n>` |
| **Coordinación** | La raíz del workspace | Sólo archivos de plataforma (planes, migraciones de carpetas, limpieza) | `coord` |

**Anti-patrón: la sesión de larga vida por repo.** Una sesión abierta semanas
en `backend/<repo>` acumula contexto de muchos issues, trabaja en la copia
principal, deja ramas locales "esperando OK", archivos sin commit que después
nadie reconoce y procesos corriendo. Si un repo necesita una sesión de
mantenimiento, se abre como sesión de issue sobre un issue de mantenimiento y
se cierra al terminarlo.

## 4. Estados de un agente

| Estado | Significa | Lo marca |
|---|---|---|
| `trabajando` | Ejecutando un turno | Hook al iniciar el turno |
| `esperando-ok` | Pide permiso o una decisión a su persona | Hook `Notification` |
| `en-reposo` | Terminó el turno; espera la próxima indicación | Hook `Stop` |
| `bloqueado` | No puede seguir sin algo externo (otro issue, un acceso) | El agente, por MCP (`report_status`) |
| `colgado` | Sin latido en más de N minutos estando `trabajando` | El tracker (§7) |
| `terminada` | La sesión cerró | Hook `SessionEnd` |

`esperando-ok` es el estado que más tiempo hace perder: el agente está listo y
nadie lo ve. Es la primera alerta que se implementa (§12).

## 5. Paralelismo sin pisarse

| Regla | Por qué |
|---|---|
| Una sesión por issue, nunca dos en el mismo worktree | Dos agentes editando el mismo árbol se pisan sin aviso |
| La copia principal de cada repo no se toca | Es la base para crear worktrees; si está sucia, todo lo que sale de ahí arrastra basura |
| En `docs`, cada sesión escribe sólo la carpeta de su issue | El índice de git es uno por clon: dos sesiones commiteando en el mismo clon mezclan cambios |
| Los archivos agregados (índices, rollout) los actualiza una persona o un job | Mismo motivo |
| **Nada queda sólo local:** lo que espera aprobación va en un MR en borrador | Una rama sin push se pierde con el disco y nadie más la ve |
| **Lo que la sesión levanta, la sesión lo baja** (servidores de desarrollo, contenedores, comandos largos) | Un `ng serve` o un `gcloud` colgado bloquea archivos y puertos días después |
| Lo que despliega, las migraciones a prod y los tags los hace una persona (tabla de abajo) | Responsabilidad y reversibilidad |
| El código vive en el workspace (`docs/01`), nunca en OneDrive ni similares | La sincronización bloquea `.git` y deja carpetas de sólo lectura que git no puede borrar |
| Rutas relativas a la raíz del workspace, con `/`, en docs, `AGENTS.md` y mensajes entre sesiones | Cada persona tiene otra raíz u otro sistema operativo |

**Acciones que despliegan.** Un agente no las hace nunca, ni siquiera como paso
"obvio" de otra tarea: propone el comando y lo corre una persona. Push a una
rama de feature y abrir un MR/PR no despliegan en ninguna plantilla.

| Acción | Qué despliega | Dónde (según la plantilla y su `deploy_target`) |
|---|---|---|
| Push de un tag `prod-v*` | **Producción** | `go-grpc-service` y `api-gateway` (automático salvo migraciones pendientes); `angular-app` y `astro-site` con Coolify o Cloud Run; `android-app` (pista interna de prod y producción escalonada con aprobación) |
| Push o merge a `main` | **Producción** | `angular-app` y `astro-site` con Firebase Hosting; el sitio del repo `docs` |
| Push de un tag `qa-v*` | QA | Todas las que despliegan (en `android-app`, la pista interna de QA) |
| Push de un tag `v*` | Publica paquetes de contratos que otros consumen | `protos` |
| `workflow_dispatch` / pipeline manual de e2e | Pruebas contra un ambiente (`@smoke` en prod) | `e2e-tests` |
| Comandos de deploy o rollback locales (`npm run deploy:*`, `scripts/rollback.sh`, API de Coolify) | El ambiente que apunten | Fallback de emergencia; sólo personas |

Cada repo generado lo repite en la sección «Deploy» de su `AGENTS.md`, y el
`AGENTS.md` de plataforma lo resume para el proyecto.

## 6. El tracker

El tracker es la fuente de verdad de **qué se está haciendo y quién**. El
estándar define el protocolo; cualquier tracker que lo cumpla sirve. La
implementación de referencia es **Tekitla** (`tekitla-mcp`).

Lo que el tracker sabe de cada sesión:

| Campo | Ejemplo |
|---|---|
| Actor dueño | La persona que abrió la sesión |
| Herramienta | `claude-code`, `codex`, `cloud` |
| Máquina y carpeta | `PC-01`, `worktrees/issue-231` (relativa a la raíz) |
| Rama e issue | `feat/issue-231-autorizacion` → `RND-231` |
| Estado y último latido | `esperando-ok`, hace 3 min |
| Resumen del último turno | Una o dos líneas, que escribe el hook `Stop` |

**Ligar sesión e issue:** por el nombre de la rama (`feat/issue-<n>-<slug>`) o
el nombre de la sesión (`issue-<n>`). Sin issue reconocible, la sesión aparece
como "sin issue" y eso ya es una señal.

**Tomar un issue (`claim`):** un agente toma un issue con un préstamo que se
renueva con el latido. Si el agente cuelga, el préstamo vence y el issue vuelve a
quedar libre. Un issue tiene un solo agente implementador a la vez.

**Herramientas MCP del protocolo.** Un tracker cumple el estándar si su
servidor MCP (`docs/15` §6–§7) ofrece al menos estas herramientas, con estos
nombres. La base común (`templates/_base`) las da de alta en `.mcp.json` como
servidor `tracker` y les pone permisos:

| Herramienta | Qué hace | Permiso en `_base` |
|---|---|---|
| `list_issues` | Issues con filtros (estado, proyecto, asignado) y cursor | `allow` |
| `get_issue` | Un issue con su descripción, criterios y estado | `allow` |
| `next_issue` | El siguiente issue libre por prioridad y rank (no lo toma) | `allow` |
| `report_status` | Estado y resumen de la sesión propia (§4) | `allow` |
| `claim_issue` | Toma un issue con préstamo | Pide confirmación |
| `release_issue` | Suelta un issue tomado | Pide confirmación |

Un tracker puede ofrecer más; lo que borra o cierra pide confirmación o se
niega por repo.

**Argumentos de `report_status`.** Los usan los hooks de `dev-agentes` (§7) y
el agente cuando se declara `bloqueado`:

| Argumento | Obligatorio | Contenido |
|---|---|---|
| `session_id` | Sí | Id de la sesión en su herramienta |
| `state` | Sí | `trabajando`, `esperando-ok`, `en-reposo`, `bloqueado` o `terminada` (`colgado` lo pone el tracker) |
| `at` | Sí | Momento del evento, RFC 3339 en UTC. El tracker descarta un reporte más viejo que el último que tiene: los hooks no esperan la respuesta y pueden llegar desordenados |
| `tool` | No | `claude-code`, `codex`, `cloud` |
| `name` | No | Nombre de la sesión (`issue-42`, `review-42`, `coord`) |
| `host` | No | Nombre de la máquina |
| `cwd` | No | Carpeta de la sesión, relativa a la raíz del workspace (`worktrees/issue-42`, `docs/01`) |
| `branch` | No | Rama actual (`feat/issue-42-descuentos`) |
| `issue` | No | Número del issue (`42`), deducido de la rama o de la carpeta; el tracker lo traduce a su clave |
| `summary` | No | Hasta 500 caracteres: resumen del turno (`en-reposo`), qué espera (`esperando-ok`) o qué lo bloquea (`bloqueado`) |
| `pending` | No | Al cerrar: lo que quedó sólo local. `{"unpushed": ["orders-service feat/issue-42-x"], "uncommitted": ["api-gateway (3)"]}` |

Un `report_status` con un `session_id` nuevo registra la sesión. Cada reporte
cuenta como latido.

**Lo que el tracker automatiza** (cada uno se especifica en el tracker):

- MR/PR abierto → `En revisión`; todos mergeados → `Testing` (GitLab y GitHub).
- Agente libre pide trabajo (`next_issue`) → el siguiente por prioridad y rank.
- Avisos: `esperando-ok` sin respuesta, `colgado`, `bloqueado`.
- Reporte diario por proyecto y por agente.

## 7. Plugin `dev-agentes` v2

Los hooks reportan siempre, aunque el modelo no se acuerde; las skills son lo
que el agente decide usar.

| Pieza | Evento o comando | Qué hace |
|---|---|---|
| Hook | `SessionStart` | Registra la sesión en el tracker (actor, herramienta, carpeta, rama) y la liga al issue; estado `en-reposo` |
| Hook | `UserPromptSubmit` | Estado `trabajando` + latido |
| Hook | `PostToolUse` | Latido mientras trabaja, como mucho uno por minuto (un turno largo no queda `colgado`) |
| Hook | `Notification` | Estado `esperando-ok` |
| Hook | `Stop` | Estado `en-reposo` + resumen del turno |
| Hook | `SessionEnd` | Estado `terminada`; avisa si quedan ramas sin push, cambios sin commit o procesos que la sesión levantó |
| Skill | `/issue-start <n>` | Worktrees + `claim` del issue + nombre de sesión |
| Skill | `/cerrar-issue` | Evidencia en el issue, `release`, borrar worktrees |
| Skill | `/coordinar` | Pregunta a todas las sesiones activas su estado y junta las respuestas (§9) |

Los hooks no bloquean nunca: si el tracker no responde, se anota y se sigue.
Sin tracker configurado, no hacen nada. Los hooks de estado (✅ en
`dev-agentes` 0.2.0) llaman a `report_status` (§6) con `TRACKER_MCP_URL` y
`TRACKER_TOKEN`, las mismas variables del `.mcp.json` (`docs/15` §4).
`Notification` reporta `esperando-ok` sólo en pedidos de permiso y preguntas
al usuario, no en el aviso de inactividad. Lo que el hook `SessionEnd` no
puede saber son los procesos que la sesión levantó: esa parte del aviso sigue
siendo de la regla de §5. Codex y los agentes en la nube no
tienen estos hooks: reportan por el MCP del tracker (`docs/15`) y se ligan por
la rama.

## 8. Contexto para cualquier herramienta: `AGENTS.md`

Claude Code lee `CLAUDE.md`; Codex y otras herramientas leen `AGENTS.md`. Para
no mantener dos textos:

- **`AGENTS.md` es la fuente**, en cada nivel de la plataforma y en cada repo
  (mismo layout y mismos límites de tamaño que `docs/01`).
- **`CLAUDE.md` importa `AGENTS.md`** (`@AGENTS.md` en la primera línea) y
  agrega sólo lo propio de Claude Code (skills, hooks, permisos).
- En cada repo, la plantilla trae `AGENTS.md` y la base común (`_base`) el
  `CLAUDE.md`. En la raíz, `backend/` y `frontend/`, la fuente vive en el repo
  de documentación (`docs/workspace/`) y `bootstrap` escribe `CLAUDE.md` con un
  import y `AGENTS.md` como copia (`docs/01`).

## 9. Coordinar varias sesiones

Antes de algo que afecta a todas (mover carpetas, cambiar de rama base, una
migración de plataforma), la sesión `coord`:

1. **Avisa** a todas las sesiones activas: qué va a pasar, qué no deben hacer
   mientras tanto (no levantar procesos, no empezar trabajo nuevo).
2. **Pide un reporte de estado** con este formato, una línea:
   `<sesión>: listo | pendiente — <ramas sin push> · <cambios sin commit> · <procesos>`
3. **Junta** las respuestas en una tabla para la persona: qué se puede cerrar,
   qué queda sólo local, qué decisiones están pendientes.
4. **No toca** lo que una sesión declara ajeno o pendiente de aprobación: lo
   copia o lo deja tal cual.

Con el tracker, los pasos 2 y 3 son una consulta; sin tracker, se hace con
mensajes entre sesiones (`/coordinar`).

## 10. Roles

- **Implementador**: la sesión del issue.
- **Revisor**: `/code-review` en el worktree, o una sesión de revisión sobre el
  diff del MR. Nunca edita.
- **Coordinador**: la sesión `coord`; planifica, coordina y limpia. No
  implementa features.
- **Humano**: aprueba el plan, responde los `esperando-ok`, aprueba el MR, aplica
  migraciones a prod y taggea `prod-v*`.

## 11. Crear un servicio o app nuevos

1. Issue con nombre, dominio, puerto y schema.
2. `copier copy` desde la plantilla (ver `02-repositorios-gitlab-github.md` §6).
3. Crear el repo remoto y aplicar la configuración obligatoria (`docs/02` §4).
4. Infra de una vez: `docs/ci-cd-setup.md` del repo generado.
5. Agregarlo a `docs/workspace/repos.txt` y al mapa del `AGENTS.md` de
   plataforma (mismo MR/PR) para que el resto del equipo lo clone.

## 12. Decisiones abiertas y fases

**Decisiones abiertas**

- [ ] N minutos sin latido para `colgado` (propuesta: 15)
- [ ] Duración del préstamo de un `claim` (propuesta: 30 min, renovable)
- [ ] Canal de avisos: push del navegador, email o chat
- [ ] Si una sesión de revisión puede comentar en el MR (sigue sin editar código)

**Fases**

1. **Forma de trabajo:** este documento aprobado, `AGENTS.md` en cada plantilla
   y en `docs/workspace/`, `CLAUDE.md` con `@AGENTS.md` desde `_base`. 🔨
   construida, falta publicar.
2. **Estado visible:** tracker con sesiones y estados; hooks `SessionStart`,
   `UserPromptSubmit`, `Notification`, `Stop`, `SessionEnd`; aviso de `esperando-ok`.
3. **Trabajo asignado:** `claim`/`release`, `/issue-start`, `/cerrar-issue`, `next_issue`.
4. **Automatización:** estados por MR/PR, avisos de `colgado` y `bloqueado`, reporte diario.
5. **Coordinación:** `/coordinar` sobre el tracker; agentes en la nube y Codex reportando por MCP.
