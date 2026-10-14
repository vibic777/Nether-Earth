# Контрибьютор: vibic777
# Брандмауэр Windows для сетевой игры Nether Earth Reloaded (LAN).
# Запуск:   powershell -ExecutionPolicy Bypass -File tools\firewall.ps1 [-Port 24680] [-DiscoveryPort 24681] [-Exe путь] [-Remove]
# Скрипт сам запросит права администратора. Правила: входящий UDP на порт игры и порт поиска,
# плюс разрешение для exe (если найден). Профили: Частная и Доменная (в публичных сетях закрыто).
param(
    [int]$Port = 24680,
    [int]$DiscoveryPort = 24681,
    [string]$Exe = "",
    [switch]$Remove
)
$ErrorActionPreference = "Stop"
$Prefix = "Nether Earth Reloaded"

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $args2 = @("-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-Port", $Port, "-DiscoveryPort", $DiscoveryPort)
    if ($Exe -ne "") { $args2 += @("-Exe", "`"$Exe`"") }
    if ($Remove) { $args2 += "-Remove" }
    Start-Process powershell -Verb RunAs -ArgumentList $args2 -Wait
    exit
}

Get-NetFirewallRule -DisplayName "$Prefix*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
if ($Remove) {
    Write-Host "Правила '$Prefix' удалены."
    exit
}

if ($Exe -eq "") {
    $root = Split-Path -Parent $PSScriptRoot
    $Exe = Join-Path $root "build\windows\NetherEarthReloaded.exe"
}

New-NetFirewallRule -DisplayName "$Prefix - игра UDP $Port" -Direction Inbound -Protocol UDP -LocalPort $Port -Action Allow -Profile Private,Domain | Out-Null
New-NetFirewallRule -DisplayName "$Prefix - поиск UDP $DiscoveryPort" -Direction Inbound -Protocol UDP -LocalPort $DiscoveryPort -Action Allow -Profile Private,Domain | Out-Null
if (Test-Path $Exe) {
    New-NetFirewallRule -DisplayName "$Prefix - программа" -Direction Inbound -Program $Exe -Action Allow -Profile Private,Domain | Out-Null
    Write-Host "Разрешена программа: $Exe"
}
Write-Host "Готово: UDP $Port (игра) и $DiscoveryPort (поиск) открыты для частных сетей."
Write-Host "Если сеть помечена как Общественная — смените профиль на Частная в параметрах Windows."
