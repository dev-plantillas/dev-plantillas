<#
.SYNOPSIS
  Crea los worktrees de un issue (docs/03 §1). Envoltorio de
  plugins/dev-agentes/skills/nueva-sesion/scripts/nueva-sesion.ps1, que es la
  implementación: mismos parámetros (-Herdr abre además la sesión en herdr).
.EXAMPLE
  .\scripts\new-worktree.ps1 -Base C:\dev\mi-org -Issue 42 -Slug descuentos -Repos backend\protos,backend\orders-service
#>
& (Join-Path $PSScriptRoot '..\plugins\dev-agentes\skills\nueva-sesion\scripts\nueva-sesion.ps1') @args
exit $LASTEXITCODE
