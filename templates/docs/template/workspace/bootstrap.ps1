# Arma (o actualiza) el workspace en Windows.
#
#   git clone <url>/docs.git C:\dev\<org>\docs
#   C:\dev\<org>\docs\workspace\bootstrap.ps1
#
# La raíz del workspace es la carpeta que contiene a docs\. Es idempotente:
# clona los repos de repos.txt que falten y refresca los archivos de contexto
# de la raíz, backend\ y frontend\ (correrlo después de cada `git pull` de docs
# que cambie docs\workspace\). Nunca toca un repo que ya existe.

$ErrorActionPreference = 'Stop'
$ws   = $PSScriptRoot                                   # <raíz>\docs\workspace
$root = Split-Path (Split-Path $ws -Parent) -Parent

if ($root -match '(?i)onedrive|dropbox|icloud') {
    throw "El workspace está dentro de una carpeta sincronizada ($root). Movelo, p. ej. a C:\dev\<org>."
}
Write-Host "Workspace: $root"

foreach ($d in 'backend', 'frontend', 'worktrees') { New-Item -ItemType Directory -Force (Join-Path $root $d) | Out-Null }

# 1) Repos
foreach ($line in Get-Content (Join-Path $ws 'repos.txt')) {
    $line = $line.Trim()
    if (-not $line -or $line.StartsWith('#')) { continue }
    $dir, $url = $line -split '\s+', 2
    $dest = Join-Path $root $dir
    if (Test-Path (Join-Path $dest '.git')) { Write-Host "  ok      $dir"; continue }
    Write-Host "  clonar  $dir"
    git clone --quiet $url $dest
    if ($LASTEXITCODE -ne 0) { Write-Warning "No se pudo clonar $url (¿acceso al repo o clave SSH?)" }
}

# 2) Contexto de agentes en la raíz, backend\ y frontend\.
#    CLAUDE.md importa la fuente versionada (un `git pull` de docs alcanza);
#    AGENTS.md es una copia para herramientas que no siguen imports (Codex).
$aviso = '<!-- Generado por docs/workspace/bootstrap: no editar. Se cambia en docs/workspace/ con un MR/PR. -->'
$capas = @(
    @{ dir = '';         src = 'AGENTS.md';          imp = '@docs/workspace/CLAUDE.md' },
    @{ dir = 'backend';  src = 'backend\AGENTS.md';  imp = '@../docs/workspace/backend/AGENTS.md' },
    @{ dir = 'frontend'; src = 'frontend\AGENTS.md'; imp = '@../docs/workspace/frontend/AGENTS.md' }
)
foreach ($c in $capas) {
    $dst = if ($c.dir) { Join-Path $root $c.dir } else { $root }
    Set-Content (Join-Path $dst 'CLAUDE.md') "$($c.imp)`n" -Encoding utf8 -NoNewline
    $copia = $aviso + "`n`n" + (Get-Content (Join-Path $ws $c.src) -Raw)
    Set-Content (Join-Path $dst 'AGENTS.md') $copia -Encoding utf8 -NoNewline
}
Write-Host "Contexto de agentes actualizado en la raíz, backend\ y frontend\."
Write-Host "Listo. Siguiente: leer docs\workspace\README.md."
