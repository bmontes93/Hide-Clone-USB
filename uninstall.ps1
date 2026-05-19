<#
    Desinstalador de la solución USB Auto-Sync Service
#>

$installPath = 'C:\ProgramData\USBSync'
$taskName = 'Infrastructure\USBSyncService'

try {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Output "Tarea programada '$taskName' removida."
    }
    else {
        Write-Output "No se encontró la tarea programada '$taskName'."
    }

    if (Test-Path $installPath) {
        Remove-Item -Path $installPath -Recurse -Force -ErrorAction Stop
        Write-Output "Carpeta de instalación '$installPath' eliminada."
    }
    else {
        Write-Output "La carpeta de instalación '$installPath' no existe."
    }
}
catch {
    Write-Error "Error durante la desinstalación: $($_.Exception.Message)"
    exit 1
}
