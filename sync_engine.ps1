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
    $dir = Get-Item $Path
    $dir.Attributes = 'Directory','Hidden','System'
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
            DriveLetter = $driveLetter
            VolumeName  = $_.VolumeName
        }
    }
}

function Get-VolumeSerial {
    param([string]$DriveLetter)
    try {
        $letter = $DriveLetter.TrimEnd(':')
        $volume = Get-Volume -DriveLetter $letter -ErrorAction Stop
        return $volume.SerialNumber
    }
    catch {
        try {
            $disk = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$DriveLetter'" -ErrorAction Stop
            return $disk.SerialNumber
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

    $usbVolumes = Get-UsbVolumes
    if (-not $usbVolumes) {
        Write-Log 'No se detectaron unidades USB removibles listas.'
        return
    }

    foreach ($volume in $usbVolumes) {
        $driveLetter = $volume.DriveLetter
        $serial = Get-VolumeSerial -DriveLetter $driveLetter
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
