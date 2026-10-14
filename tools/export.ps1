param(
    [ValidateSet("all", "windows", "linux", "android")]
    [string]$Target = "all"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Godot = $env:GODOT
if (-not $Godot) {
    $Cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($Cmd) { $Godot = $Cmd.Source }
}
if (-not $Godot) {
    $Bundled = Join-Path $env:TEMP "godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    if (Test-Path $Bundled) { $Godot = $Bundled }
}
if (-not $Godot) {
    Write-Error "Godot 4.7 not found. Set GODOT to Godot_v4.7.2-stable_win64.exe. See docs/deploy.md."
}

$Version = (Get-Content (Join-Path $Root "VERSION") -Raw).Trim()
$Commit = (git -C $Root rev-parse --short HEAD).Trim()
$Date = Get-Date -Format "yyyy-MM-dd HH:mm"
@{version = $Version; date = $Date; commit = $Commit} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Root "data/version.json")
$Win4 = ($Version -replace '-.*$', '') + ".0"
$Presets = Join-Path $Root "export_presets.cfg"
(Get-Content $Presets) -replace '^application/file_version=.*', "application/file_version=""$Win4""" -replace '^application/product_version=.*', "application/product_version=""$Win4""" | Set-Content $Presets
New-Item -ItemType Directory -Force -Path "build/windows", "build/linux", "build/android" | Out-Null

function Export-Preset([string]$Name, [string]$OutFile) {
    Write-Host "Export $Name -> $OutFile"
    & $Godot --headless --path $Root --export-release $Name $OutFile
    if ($LASTEXITCODE -ne 0) {
        throw "Export failed: $Name"
    }
}

if ($Target -eq "all" -or $Target -eq "windows") {
    Export-Preset "Windows Desktop" "build/windows/NetherEarthReloaded-$Version.exe"
}
if ($Target -eq "all" -or $Target -eq "linux") {
    Export-Preset "Linux" "build/linux/NetherEarthReloaded-$Version.x86_64"
}
if ($Target -eq "all" -or $Target -eq "android") {
    Export-Preset "Android" "build/android/NetherEarthReloaded-$Version.apk"
}
