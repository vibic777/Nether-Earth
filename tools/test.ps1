# Контрибьютор: vibic777
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT
if (-not $godot) {
	$godot = Join-Path $env:TEMP "godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $godot)) {
	Write-Error "Godot 4.7.2 не найден. Положите консольный exe в TEMP или задайте GODOT."
}
& $godot --headless --path $root --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path $root -- --test
exit $LASTEXITCODE
