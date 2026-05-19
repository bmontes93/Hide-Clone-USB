# USB Auto-Sync Service

Solución de sincronización silenciosa y orientada a eventos para dispositivos USB en Windows.

## Contenido
- `USB_Sync_Task.xml`: definición de la tarea del Programador de Tareas.
- `sync_engine.ps1`: motor de sincronización que ejecuta `robocopy` en el contexto `SYSTEM`.
- `install.ps1`: script de despliegue para copiar los artefactos y registrar la tarea.

## Despliegue
Ejecutar PowerShell como Administrador en la carpeta del repositorio y luego:

```powershell
.\\install.ps1
```

## Desinstalación
Para eliminar el servicio y todos los archivos asociados, ejecutar PowerShell como Administrador en la carpeta del repositorio:

```powershell
.\\uninstall.ps1
```

## Comportamiento
- Detecta unidades removibles de tipo USB.
- Crea un almacén local oculto en `C:\ProgramData\USBSync\Storage\<Serial>`.
- Usa `robocopy` con `/MT:32`, `/B`, `/R:1`, `/W:1` y registros en `sync_log.txt`.
- La tarea se ejecuta como `NT AUTHORITY\SYSTEM` y está oculta en la UI.

## Notas
- La tarea se dispara por eventos del canal `Microsoft-Windows-DriverFrameworks-UserMode/Operational`.
- El servicio no utiliza polling continuo y permanece inactivo hasta que se dispara el evento.
