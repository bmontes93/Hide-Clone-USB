<#
    Desinstalador de la solución USB Auto-Sync Service
#>

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Acceso Denegado: Este script requiere ejecutarse en una consola de PowerShell como Administrador."
    exit 1
}

$installPath = 'C:\ProgramData\USBSync'
$taskName = 'USBSyncService'

try {
    # Buscar la tarea programada dinámicamente en cualquier ruta
    $targetTasks = Get-ScheduledTask | Where-Object { $_.TaskName -eq $taskName }
    if ($targetTasks) {
        foreach ($task in $targetTasks) {
            Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
            Write-Output "Tarea programada '$($task.TaskPath)$($task.TaskName)' removida."
        }
    }
    else {
        Write-Output "No se encontró la tarea programada '$taskName' en el sistema."
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
