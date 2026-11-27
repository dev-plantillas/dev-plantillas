<#
.SYNOPSIS
  Prepara el trabajo de un issue (docs/03 §1 y §13): worktrees y, con -Herdr,
  workspace de herdr + Claude Code con nombre + primer mensaje.

.DESCRIPTION
  Dos layouts (docs/01):
  - Workspace de varios repos (la raíz tiene worktrees/): un worktree por repo
    de -Repos en <Base>/worktrees/issue-<n>/<repo>.
  - Repo único (la raíz es un repo): <Base>-wt/issue-<n>, carpeta hermana.
  Rama <Type>/issue-<n>-<Slug> desde origin/main (en el repo docs, docs/issue-<n>-<Slug>).
  Si el worktree ya existe, lo reutiliza.

  Con -Herdr (dentro de herdr, HERDR_ENV=1): abre el workspace "<proyecto> #<n>"
  en la carpeta del issue, arranca `claude -n issue-<n>` como agente herdr
  "<proyecto>-issue-<n>" y, con -Prompt, le manda el primer mensaje. Si Claude
  pregunta si confía en la carpeta, avisa y espera a que la persona acepte:
  nunca la acepta solo.

.EXAMPLE
  nueva-sesion.ps1 -Base C:\dev\mi-org -Issue 42 -Slug descuentos -Repos backend\orders-service,docs
.EXAMPLE
  nueva-sesion.ps1 -Base C:\dev\mi-repo -Issue 7 -Slug reglas -Herdr -Prompt "Trabajá el issue 7" -Focus
#>
param(
  [Parameter(Mandatory)] [int] $Issue,
  [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')] [string] $Slug,
  [string[]] $Repos = @(),
  [string] $Base = (Get-Location).Path,
  [ValidateSet('feat', 'fix', 'chore', 'docs')] [string] $Type = 'feat',
  [switch] $Herdr,
  [string] $Prompt = '',
  [switch] $Focus
)
$ErrorActionPreference = 'Stop'

# Con `pwsh -File`, "-Repos a,b" llega como un solo string.
$Repos = @($Repos | ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ })
$Base =(Resolve-Path $Base).Path.TrimEnd('\', '/')
if ($Base -match '(?i)onedrive|dropbox|icloud') {
  throw "El workspace no puede vivir en OneDrive, Dropbox ni iCloud (docs/01): $Base"
}
$proyecto = (Split-Path $Base -Leaf).ToLower()
$branch = "$Type/issue-$Issue-$Slug"
$multi = Test-Path (Join-Path $Base 'worktrees')

function Add-Worktree([string] $repo, [string] $destino, [string] $rama) {
  if (Test-Path $destino) { Write-Host "Reutilizo $destino"; return }
  git -C $repo fetch origin main --quiet
  if (git -C $repo branch --list $rama) { git -C $repo worktree add $destino $rama }
  else { git -C $repo worktree add --no-track $destino -b $rama origin/main }
  if ($LASTEXITCODE -ne 0) { throw "No se pudo crear el worktree $destino" }
}

if ($multi) {
  if ($Repos.Count -eq 0) { throw "En un workspace de varios repos, -Repos es obligatorio (ej. backend\orders-service,docs)" }
  $cwd = Join-Path $Base (Join-Path 'worktrees' "issue-$Issue")
  New-Item -ItemType Directory -Force $cwd | Out-Null
  foreach ($r in $Repos) {
    $repo = Join-Path $Base $r
    if (-not (Test-Path (Join-Path $repo '.git'))) { throw "No es un repo: $repo" }
    $nombre = Split-Path $r -Leaf
    $rama = if ($nombre -eq 'docs') { "docs/issue-$Issue-$Slug" } else { $branch }
    Add-Worktree $repo (Join-Path $cwd $nombre) $rama
  }
} else {
  if (-not (Test-Path (Join-Path $Base '.git'))) { throw "No es un repo ni un workspace con worktrees/: $Base" }
  if ($Repos.Count -gt 0) { throw "-Repos es para un workspace de varios repos; $Base es un repo único" }
  $cwd = Join-Path "$Base-wt" "issue-$Issue"
  New-Item -ItemType Directory -Force (Split-Path $cwd) | Out-Null
  Add-Worktree $Base $cwd $branch
}

$sesion = "issue-$Issue"
$salida = [ordered]@{ proyecto = $proyecto; issue = $Issue; cwd = $cwd; sesion = $sesion }

if (-not $Herdr) {
  Write-Host "`nAbrí la sesión en: $cwd   (claude -n $sesion)"
  [pscustomobject]$salida | ConvertTo-Json -Compress
  exit 0
}

if ($env:HERDR_ENV -ne '1') { throw "-Herdr necesita correr dentro de herdr (HERDR_ENV=1). Los worktrees quedaron en $cwd" }
function Invoke-Herdr([string[]] $HerdrArgs) {
  $out = & herdr @HerdrArgs 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw "herdr $($HerdrArgs -join ' ') falló: $out" }
  return $out | ConvertFrom-Json
}

# Nombre del agente en herdr: <proyecto>-issue-<n>, máx. 32 caracteres.
$agente = "$proyecto-$sesion"
if ($agente.Length -gt 32) { $agente = $agente.Substring(0, 32).TrimEnd('-') }

$ws = Invoke-Herdr @('workspace', 'create', '--cwd', $cwd, '--label', "$proyecto #$Issue", $(if ($Focus) { '--focus' } else { '--no-focus' }))
$pane = $ws.result.root_pane.pane_id
Write-Host "Workspace $($ws.result.workspace.workspace_id) ($proyecto #$Issue) en $cwd"

$start = & herdr agent start $agente --kind claude --pane $pane --timeout 60000 -- -n $sesion 2>&1 | Out-String
if ($start -match 'agent_not_ready') {
  # Casi siempre es la pregunta de confianza de una carpeta nueva: la contesta una persona.
  Write-Warning "Claude espera confirmación en '$proyecto #$Issue' (¿confiás en esta carpeta?). Aceptala en ese workspace; espero hasta 5 min."
  & herdr notification show "Nueva sesión $proyecto #$Issue" --body "Claude pide confirmar la carpeta" 2>&1 | Out-Null
  & herdr agent wait $agente --until idle --timeout 300000 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "La sesión $agente no quedó lista; revisá el workspace '$proyecto #$Issue'." }
} elseif ($LASTEXITCODE -ne 0) { throw "No se pudo arrancar Claude: $start" }
Write-Host "Claude '$sesion' listo (agente herdr: $agente)"

if ($Prompt) {
  Invoke-Herdr @('agent', 'prompt', $agente, $Prompt) | Out-Null
  Write-Host 'Primer mensaje enviado.'
}
$salida.pane = $pane
$salida.agente = $agente
[pscustomobject]$salida | ConvertTo-Json -Compress
