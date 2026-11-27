<#
.SYNOPSIS
  Cierra una sesión de issue abierta con nueva-sesion.ps1 -Herdr, sólo si
  terminó y no deja nada sin guardar (docs/03 §13).

.DESCRIPTION
  Sin -Confirmar sólo revisa e informa. Con -Confirmar, si todo está bien:
  manda /exit a Claude (queda para `claude --resume`) y cierra el workspace.
  NO borra worktrees: eso se hace cuando el MR/PR está mergeado.

  Revisa:
    1. El workspace es de issue ("<proyecto> #<n>") y no es el de quien llama.
    2. Claude está idle o done (no working, blocked ni unknown).
    3. No tiene marca de espera (fuente dev-espera).
    4. Ningún worktree tiene cambios sin commit ni commits sin push.
    5. Ningún proceso de la sesión escucha un puerto TCP (dev server, emulador...).

.EXAMPLE
  cerrar-sesion.ps1 -Agente mi-org-issue-42              # sólo revisa
  cerrar-sesion.ps1 -Agente mi-org-issue-42 -Confirmar   # revisa y cierra
  cerrar-sesion.ps1 -Workspace w17 -Confirmar
#>
param(
  [string] $Agente = '',
  [string] $Workspace = '',
  [switch] $Confirmar
)
$ErrorActionPreference = 'Stop'
if (-not $Agente -and -not $Workspace) { throw 'Indicá -Agente <nombre en herdr> o -Workspace <id>.' }

function Herdr-Json([string[]] $a) {
  $out = & herdr @a 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw "herdr $($a -join ' '): $out" }
  $out | ConvertFrom-Json
}

$agentes = (Herdr-Json @('agent', 'list')).result.agents
$ag = if ($Agente) {
  $agentes | Where-Object { $_.name -eq $Agente -or $_.agent_name -eq $Agente -or $_.pane_id -eq $Agente } | Select-Object -First 1
} else {
  $agentes | Where-Object { $_.workspace_id -eq $Workspace } | Select-Object -First 1
}
if (-not $ag -and $Agente) { $ag = (Herdr-Json @('agent', 'get', $Agente)).result.agent }
if (-not $ag) { throw "No encuentro la sesión ($Agente$Workspace) en herdr." }

$wsId = $ag.workspace_id
$ws = (Herdr-Json @('workspace', 'get', $wsId)).result.workspace
$problemas = [System.Collections.Generic.List[string]]::new()

# 1. Sólo workspaces de issue, nunca el propio.
if ($ws.label -notmatch ' #\d+$') { $problemas.Add("'$($ws.label)' no es un workspace de issue: las sesiones principales las cierra la persona.") }
if ($env:HERDR_WORKSPACE_ID -and $env:HERDR_WORKSPACE_ID -eq $wsId) { $problemas.Add('Es el workspace de quien llama: una sesión no se cierra a sí misma.') }

# 2. Estado del agente.
if ($ag.agent_status -notin @('idle', 'done')) { $problemas.Add("Claude está '$($ag.agent_status)'.") }

# 3. Marca de espera.
$json = $ag | ConvertTo-Json -Depth 10
if ($json -match '"espera_tipo"\s*:\s*"([^"]+)"' -or $json -match '"espera"\s*:\s*"([^"]+)"') {
  $problemas.Add("Tiene marca de espera: $($Matches[1]).")
}

# 4. Worktrees: el cwd del panel o sus subcarpetas que sean repos.
$cwd = $ag.cwd.TrimEnd('\', '/')
$repos = @()
if (Test-Path (Join-Path $cwd '.git')) { $repos = @($cwd) }
else { $repos = @(Get-ChildItem $cwd -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName '.git') } | ForEach-Object FullName) }
if (-not $repos) { $problemas.Add("No encontré worktrees en $cwd para revisar.") }
foreach ($r in $repos) {
  $nombre = Split-Path $r -Leaf
  $sucio = git -C $r status --porcelain 2>$null
  if ($sucio) { $problemas.Add("$($nombre): $(@($sucio).Count) cambios sin commit.") }
  git -C $r rev-parse --abbrev-ref '@{u}' 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    $adelante = [int](git -C $r rev-list --count '@{u}..HEAD')
    if ($adelante -gt 0) { $problemas.Add("$($nombre): $adelante commits sin push.") }
  } else {
    git -C $r fetch origin main --quiet 2>$null
    $adelante = [int](git -C $r rev-list --count 'origin/main..HEAD' 2>$null)
    if ($adelante -gt 0) { $problemas.Add("$($nombre): rama sin upstream con $adelante commits que no están en el remoto.") }
  }
}

# 5. Procesos de la sesión (descendientes del shell del panel) escuchando puertos.
$info = (Herdr-Json @('pane', 'process-info', '--pane', $ag.pane_id)).result.process_info
$windows = $IsWindows -or $env:OS -eq 'Windows_NT'
if ($windows) {
  $todos = @(Get-CimInstance Win32_Process | ForEach-Object { [pscustomobject]@{ Pid = [int]$_.ProcessId; Ppid = [int]$_.ParentProcessId; Name = $_.Name } })
} else {
  $todos = @(ps -A -o pid=,ppid=,comm= | ForEach-Object {
      $c = $_.Trim() -split '\s+', 3
      [pscustomobject]@{ Pid = [int]$c[0]; Ppid = [int]$c[1]; Name = $c[2] }
    })
}
$hijos = @{}
foreach ($p in $todos) { if (-not $hijos[$p.Ppid]) { $hijos[$p.Ppid] = @() }; $hijos[$p.Ppid] += $p }
$desc = @{}
$cola = [System.Collections.Generic.Queue[int]]::new()
$cola.Enqueue([int]$info.shell_pid)
while ($cola.Count) {
  $id = $cola.Dequeue()
  foreach ($h in @($hijos[$id])) { if ($h -and -not $desc[$h.Pid]) { $desc[$h.Pid] = $h; $cola.Enqueue($h.Pid) } }
}
$escuchando = if ($windows) {
  @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ Pid = [int]$_.OwningProcess; Port = $_.LocalPort } })
} else {
  @(lsof -nP -iTCP -sTCP:LISTEN -F pn 2>$null | ForEach-Object -Begin { $p = 0 } -Process {
      if ($_ -like 'p*') { $p = [int]$_.Substring(1) }
      elseif ($_ -like 'n*') { [pscustomobject]@{ Pid = $p; Port = ($_ -split ':')[-1] } }
    })
}
foreach ($c in $escuchando | Where-Object { $desc.ContainsKey($_.Pid) }) {
  $p = $desc[$c.Pid]
  $problemas.Add("Proceso levantado: $($p.Name) (pid $($p.Pid)) escucha el puerto $($c.Port).")
}

# Resultado.
$titulo = "$($ws.label) [$wsId] · $($ag.agent_status) · $cwd"
if ($problemas.Count) {
  Write-Host "NO se cierra $titulo" -ForegroundColor Yellow
  $problemas | ForEach-Object { Write-Host "  - $_" }
  exit 1
}
Write-Host "Se puede cerrar $titulo" -ForegroundColor Green
if (-not $Confirmar) { Write-Host '  (sólo revisión; agregá -Confirmar para cerrarla)'; exit 0 }

& herdr agent prompt $ag.pane_id '/exit' 2>&1 | Out-Null
Start-Sleep -Seconds 3
Herdr-Json @('workspace', 'close', $wsId) | Out-Null
Write-Host "Cerrada. Se retoma con: cd $cwd; claude --resume"
