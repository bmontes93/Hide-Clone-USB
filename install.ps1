<#
    Instalador de la solución USB Auto-Sync Service
#>

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Acceso Denegado: Este script requiere ejecutarse en una consola de PowerShell como Administrador."
    exit 1
}

$installPath = 'C:\ProgramData\USBSync'
$taskXmlPath = Join-Path $PSScriptRoot 'USB_Sync_Task.xml'

if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
}

$filesToCopy = @('sync_engine.ps1', 'USB_Sync_Task.xml')
foreach ($fileName in $filesToCopy) {
    $source = Join-Path $PSScriptRoot $fileName
    $destination = Join-Path $installPath $fileName
    Copy-Item -Path $source -Destination $destination -Force
}

$taskXmlContent = Get-Content -Raw -Path $taskXmlPath
Register-ScheduledTask -TaskName 'Infrastructure\USBSyncService' -Xml $taskXmlContent -Force

$folder = Get-Item $installPath
$folder.Attributes = 'Directory','Hidden','System'

Write-Output 'Instalación completada. La tarea USB Auto-Sync Service se ha registrado.'
