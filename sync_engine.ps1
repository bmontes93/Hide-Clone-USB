<#
    USB Auto-Sync Engine v1.0
    Diseño de Arquitectura: Event-Driven Non-Interactive Copy
#>

$ErrorActionPreference = 'Stop'

$installPath = 'C:\ProgramData\USBSync'
$globalLogFile = Join-Path $installPath 'USBSync_Service.log'

function Write-Log {
    param(
        [string]$Message,
        [string]$Path = $globalLogFile
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $Path -Value $entry
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
    # Mantener los directorios visibles (sin atributos Hidden/System) para facilitar la visualización del usuario
    $dir = Get-Item $Path -Force
    $dir.Attributes = 'Directory'
}

function Get-UsbVolumes {
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 2' | ForEach-Object {
        if ($_.ProviderName) {
            # No procesar unidades de red montadas como removibles
            return
        }
        $driveLetter = $_.DeviceID
        if (-not [System.IO.Directory]::Exists("$driveLetter\")) {
            return
        }
        [PSCustomObject]@{
            DriveLetter        = $driveLetter
            VolumeName         = $_.VolumeName
            VolumeSerialNumber = $_.VolumeSerialNumber
        }
    }
}

function Get-VolumeSerial {
    param([string]$DriveLetter)
    try {
        # En sistemas cliente modernos, Get-Volume no tiene SerialNumber. Intentamos Win32_Volume primero.
        $disk = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$DriveLetter'" -ErrorAction Stop
        if ($disk.SerialNumber) {
            return $disk.SerialNumber
        }
        # Fallback a Get-Volume en caso de requerirse
        $letter = $DriveLetter.TrimEnd(':')
        $volume = Get-Volume -DriveLetter $letter -ErrorAction Stop
        if ($volume.SerialNumber) {
            return $volume.SerialNumber
        }
        return $null
    }
    catch {
        try {
            # Último recurso: Win32_LogicalDisk
            $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = '$DriveLetter'" -ErrorAction Stop
            return $disk.VolumeSerialNumber
        }
        catch {
            return $null
        }
    }
}

function Sync-UsbDrive {
    param(
        [string]$DriveLetter,
        [string]$TargetRoot,
        [string]$Serial
    )

    Ensure-Directory -Path $TargetRoot
    
    $driveLogFile = Join-Path $installPath "sync_log_$Serial.log"

    $robocopyArgs = @(
        "$DriveLetter\",
        $TargetRoot,
        '/E',
        '/MT:32',
        '/R:1',
        '/W:1',
        '/B',
        '/NP',
        '/NFL',
        '/NDL',
        "/LOG:$driveLogFile",
        '/APPEND'
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = 'robocopy.exe'
    $startInfo.Arguments = $robocopyArgs -join ' '
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.CreateNoWindow = $true
    $startInfo.UseShellExecute = $false

    Write-Log "Iniciando sincronización desde $DriveLetter a $TargetRoot"

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $process.WaitForExit()

    $exitCode = $process.ExitCode
    if ($exitCode -ge 8) {
        Write-Log "Robocopy falló con código de salida $exitCode para $DriveLetter"
    }
    else {
        Write-Log "Robocopy completado con código de salida $exitCode para $DriveLetter"
    }
}

try {
    Ensure-Directory -Path $installPath
    Write-Log 'Inicio de ejecución del servicio USB Auto-Sync.'

    # Mitigación de condición de carrera: reintentar la detección de unidades USB por si hay retraso en el montaje (hasta 5 intentos)
    $usbVolumes = $null
    for ($i = 1; $i -le 5; $i++) {
        $usbVolumes = Get-UsbVolumes
        if ($usbVolumes) {
            Write-Log "Unidades USB detectadas con éxito en el intento ${i}."
            break
        }
        Write-Log "Intento ${i}: No se detectaron unidades USB listas. Esperando montaje de Windows..."
        Start-Sleep -Seconds 1
    }

    if (-not $usbVolumes) {
        Write-Log 'No se detectaron unidades USB removibles listas después de los reintentos.'
        return
    }

    foreach ($volume in $usbVolumes) {
        $driveLetter = $volume.DriveLetter
        
        # Intentar obtener el serial directamente de Win32_LogicalDisk o usando la función robustecida
        $serial = $volume.VolumeSerialNumber
        if (-not $serial) {
            $serial = Get-VolumeSerial -DriveLetter $driveLetter
        }
        if (-not $serial) {
            $serial = 'UNKNOWN_SERIAL'
        }

        $targetRoot = Join-Path $installPath "Storage\$serial"

        Write-Log "Procesando unidad USB $driveLetter con serial $serial"
        Sync-UsbDrive -DriveLetter $driveLetter -TargetRoot $targetRoot -Serial $serial
    }
}
catch {
    Write-Log "Error crítico: $($_.Exception.Message)"
    throw
}
finally {
    Write-Log 'Fin de ejecución del servicio USB Auto-Sync.'
}
