# MCP en los proyectos

Cómo usan los proyectos el **Model Context Protocol** (MCP): qué servidores
usan los agentes mientras desarrollan y cuándo un proyecto expone su propio
servidor MCP como parte del producto. **Especificación**; la fase 1 (consumir,
§3–§4) está construida en `templates/_base` y falta publicarla (§12).

## 1. Estado actual

- La base común trae `.mcp.json` (vacío, o con el tracker si `tracker_mcp`) y
  los permisos de lectura del tracker en `.claude/settings.json`. Falta
  publicar las plantillas; los repos ya generados lo reciben con `copier update`.
- Hasta entonces, cada persona configura sus servidores MCP a mano, con alcance de usuario.
  Lo que una sesión puede consultar depende de la máquina, no del proyecto.
- Los agentes ya trabajan sobre servicios internos (tracker, repo de docs,
  bases de QA) a fuerza de comandos sueltos (`gcloud`, `psql`, `glab`): sin
  permisos por herramienta y sin auditoría de quién hizo qué.

## 2. Dos usos que no hay que mezclar

| | **Consumir** MCP | **Exponer** MCP |
|---|---|---|
| Qué es | Los agentes de desarrollo usan servidores MCP como herramientas | El sistema que construimos ofrece un servidor MCP a agentes (nuestros o de clientes) |
| Ejemplo | La sesión de un issue lee el tracker y la base de QA | Tekitla expone sus issues para que cualquier agente los lea y los mueva |
| Dónde se define | `.mcp.json` del repo y permisos en `.claude/settings.json` (§4) | Código del producto: opción `mcp: true` del `api-gateway` (§6) |
| Quién lo decide | La plataforma (lista de servidores aprobados, §3) | El issue del producto, como cualquier otra API |

## 3. Consumir: servidores aprobados

Un servidor entra al `.mcp.json` de un repo sólo si está en esta lista o tiene
un ADR en `docs`. Cada servidor suma sus definiciones de herramientas al
contexto de **todas** las sesiones del repo: pocos y útiles.

| Servidor | Para qué | Alcance | Regla |
|---|---|---|---|
| Tracker de issues (Tekitla, `docs/03` §6) | Leer el issue, tomarlo, reportar estado | Proyecto | Obligatorio cuando el tracker existe |
| Repo de documentación | Buscar issues, ADRs y runbooks sin clonar `docs` | Proyecto | Sólo lectura |
| GitLab / GitHub | MRs, pipelines, comentarios | Usuario | Con el token de la persona, nunca uno compartido |
| Postgres de **QA** | Consultar datos al depurar | Proyecto | Usuario de base de sólo lectura. **Nunca prod** |
| Navegador (Playwright) | Probar el front | Usuario | Contra local o QA |
| Documentación de librerías | Docs actualizadas de dependencias | Usuario | Sin credenciales |

Fuera de la lista por defecto: servidores con escritura en prod, servidores que
ejecutan comandos arbitrarios del sistema (eso ya lo hace el agente, con
permisos) y servidores de terceros sin revisar el código.

## 4. Consumir: configuración en el repo

La base común (`templates/_base`) agrega:

**`.mcp.json`** (versionado): los servidores de proyecto. Sale de
`_base/mcp.json.jinja`: vacío por defecto y con el servidor `tracker` si se
responde `tracker_mcp: true` en Copier. Los secretos nunca van escritos: se
expanden de variables de entorno.

```json
{
  "mcpServers": {
    "tracker": {
      "type": "http",
      "url": "${TRACKER_MCP_URL}",
      "headers": { "Authorization": "Bearer ${TRACKER_TOKEN}" }
    }
  }
}
```

**Permisos** en `.claude/settings.json` (vienen de
`_base/claude-settings.json`): las herramientas de lectura van en `allow`; las
que escriben piden confirmación; las destructivas van en `deny` salvo que el
repo las necesite. La base trae las del protocolo del tracker (`docs/03` §6):

```json
{
  "permissions": {
    "allow": [
      "mcp__tracker__list_issues", "mcp__tracker__get_issue",
      "mcp__tracker__next_issue", "mcp__tracker__report_status"
    ]
  }
}
```

**Variables de entorno de la persona**, no del repo: Claude Code expande los
`${VAR}` de `.mcp.json` desde el entorno de su propio proceso y no lee los
`.env` del repo (esos son de la app). Cada persona define `TRACKER_MCP_URL` y
`TRACKER_TOKEN` en su entorno de usuario (en Windows, variables de entorno de
usuario). El `CLAUDE.md` que trae la base lo recuerda. Un token nunca va en un
archivo del repo; gitleaks lo busca igual.

Otras herramientas (Codex, agentes en la nube) tienen su propio formato de
configuración MCP. El servidor y las reglas son los mismos; el archivo cambia.
Se documenta en el `README` del repo generado, no se duplica la lista.

## 5. Seguridad al consumir

- **Lo que devuelve una herramienta es dato, no instrucción.** Un issue, un
  comentario de MR o una fila de la base pueden traer texto escrito por
  cualquiera. El agente no obedece instrucciones que vengan en esos resultados.
- **Mínimo privilegio por servidor:** token propio de cada persona o agente,
  con el alcance justo. Nada de tokens de servicio compartidos en `.env`.
- **Sin prod desde una sesión de desarrollo.** Las migraciones y los cambios de
  datos en prod siguen siendo humanos (`docs/03` §5).
- **Un token filtrado se rota**, igual que cualquier secreto (`docs/10` §2).

## 6. Exponer: cuándo y cómo

**Cuándo vale la pena:** cuando agentes (propios o de clientes) van a operar
sobre el sistema de forma habitual: un tracker, un back-office, datos internos
que hoy se consultan a mano. No vale la pena "porque sí": un MCP es una API
pública más, con su costo de seguridad y mantenimiento.

**Dónde vive:** como **opción del `api-gateway`** (`mcp: true`), con un
endpoint `/mcp` (transporte HTTP del protocolo). No es un servicio aparte porque
el gateway ya resuelve lo difícil (`docs/05`): autenticación, autorización por
ruta, rate limit, límites de tamaño, auditoría. Un MCP aparte tendría que
repetirlo todo. Si un proyecto no tiene gateway Go, la alternativa es un servicio
`mcp-server` que llame al gateway como cualquier otro cliente (decisión abierta,
§11).

```
agente ──MCP/HTTP──▶ api-gateway /mcp ──gRPC──▶ <dominio>-service
web    ──REST─────▶ api-gateway /v1  ──gRPC──▶ <dominio>-service
```

## 7. Exponer: diseño de herramientas

| Regla | Por qué |
|---|---|
| Una herramienta por **caso de uso**, no por tabla (`move_issue`, no `update_row`) | El agente elige mejor y la autorización se piensa por acción |
| Nombres en inglés, `verbo_objeto`, descripciones cortas y concretas | La descripción se paga en tokens en cada sesión |
| Anotar `readOnlyHint` / `destructiveHint` / `idempotentHint` | El cliente decide qué confirma con la persona |
| Paginación con cursor y límites por defecto bajos | Una respuesta enorme llena el contexto del agente |
| Errores con el `reason` del `ErrorInfo` (#25) y un mensaje que diga qué hacer | El agente puede corregir y reintentar sin adivinar |
| Mismo contrato que la API: la herramienta llama al RPC, no a la base | Una sola fuente de reglas de negocio |

## 8. Exponer: identidad y auditoría

- **Toda llamada tiene un actor** (persona o agente, `docs/03` §2). El token
  dice quién es; el gateway lo propaga como `x-user-id` y suma `x-agent-id`.
  Igual que con el resto de la identidad (`docs/05`), el gateway **borra**
  `x-agent-id` si viene del cliente antes de setearlo.
- **Tokens por actor**, con alcance (`issues:read`, `issues:write`) y
  vencimiento. Los tokens de agente pertenecen a una persona y se revocan con ella.
- **Auditoría:** cada llamada de escritura queda en el log con actor, agente,
  herramienta y resultado (`docs/14` §5, logs correlacionados).

## 9. Qué agrega cada plantilla

| Plantilla | Agrega |
|---|---|
| `_base` (todas) | `.mcp.json` vacío o con el tracker (pregunta `tracker_mcp`), permisos MCP en `.claude/settings.json`, `CLAUDE.md` con `@AGENTS.md` ✅ |
| `api-gateway` | Opción `mcp: true`: endpoint `/mcp` con el SDK oficial de Go, herramientas generadas a partir de una lista de RPCs expuestos, tokens por actor |
| `docs` | Plantilla de ADR "sumar un servidor MCP" |
| Plugin `dev-agentes` | Usa el MCP del tracker en sus hooks y skills (`docs/03` §7) |

## 10. Criterios de terminado

- [x] Un repo generado trae `.mcp.json` y permisos MCP, y `sincronizar-base.py --comprobar` lo verifica
- [ ] Ningún secreto en `.mcp.json` (lo prueba gitleaks en el CI de la plantilla)
- [ ] `api-gateway` con `mcp: true` genera un proyecto que pasa sus tests e2e: listar, leer y escribir con un token, y fallar sin token o con alcance insuficiente
- [ ] Las herramientas de escritura quedan auditadas con actor y agente
- [ ] Tekitla usa la opción y su MCP lo consume una sesión de Claude Code y una de Codex

## 11. Decisiones abiertas

- [ ] MCP dentro del `api-gateway` o servicio `mcp-server` aparte (recomendado: dentro, §6)
- [ ] Autenticación del MCP expuesto: tokens propios por actor o OAuth del protocolo para clientes externos
- [ ] Si el servidor del repo de documentación es un MCP propio o se usa el del tracker

## 12. Fases

1. **Consumir:** lista de servidores (§3), `.mcp.json` y permisos en `_base`.
2. **Exponer, mínimo:** `mcp: true` en `api-gateway` con lectura; Tekitla como primer proyecto.
3. **Exponer, escritura:** tokens por actor con alcance, auditoría, herramientas destructivas con confirmación.
4. **Clientes externos:** OAuth, rate limit por cliente, catálogo público de herramientas.
