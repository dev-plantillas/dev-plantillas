<#
.SYNOPSIS
  nueva-sesion.ps1 interactivo, para un atajo de herdr (popup). docs/03 §13.
  Lista los proyectos de -Raiz (workspaces con worktrees/ y repos), pregunta
  issue, slug, tipo, repos y primer mensaje, y abre la sesión con -Herdr -Focus.
.EXAMPLE
  nueva-sesion-menu.ps1 -Raiz C:\dev
#>
param([string] $Raiz = $(if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'C:\dev' } else { Join-Path $HOME 'dev' }))
$ErrorActionPreference = 'Stop'
$proyectos = @(Get-ChildItem $Raiz -Directory |
    Where-Object { $_.Name -notlike '*-wt' -and ((Test-Path (Join-Path $_.FullName '.git')) -or (Test-Path (Join-Path $_.FullName 'worktrees'))) } |
    Select-Object -ExpandProperty FullName)
if ($proyectos.Count -eq 0) { throw "No hay proyectos en $Raiz" }
for ($i = 0; $i -lt $proyectos.Count; $i++) { Write-Host ('[{0}] {1}' -f ($i + 1), $proyectos[$i]) }
$base = $proyectos[[int](Read-Host 'Proyecto (número)') - 1]
$issue = [int](Read-Host 'Issue (número)')
$slug = Read-Host 'Slug (kebab-case, ej. reglas-firestore)'
$type = Read-Host 'Tipo [feat|fix|chore|docs] (Enter = feat)'
if (-not $type) { $type = 'feat' }
$opciones = @{ Base = $base; Issue = $issue; Slug = $slug; Type = $type; Herdr = $true; Focus = $true }
if (Test-Path (Join-Path $base 'worktrees')) {
  $repos = Read-Host 'Repos separados por coma (ej. backend\api-gateway,docs)'
  $opciones.Repos = @($repos -split '\s*,\s*' | Where-Object { $_ })
}
$prompt = Read-Host 'Primer mensaje para la sesión (Enter = ninguno)'
if ($prompt) { $opciones.Prompt = $prompt }
& (Join-Path $PSScriptRoot 'nueva-sesion.ps1') @opciones
Read-Host 'Listo. Enter para cerrar'
