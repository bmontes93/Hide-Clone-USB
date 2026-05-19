# Manual de Uso - USB Auto-Sync Service

## Índice
- [Manual de Uso - USB Auto-Sync Service](#manual-de-uso---usb-auto-sync-service)
  - [Índice](#índice)
  - [1. Visión General](#1-visión-general)
  - [2. Requisitos Previos](#2-requisitos-previos)
  - [3. Estructura de archivos](#3-estructura-de-archivos)
  - [4. Preparación](#4-preparación)
  - [5. Instalación paso a paso](#5-instalación-paso-a-paso)
  - [6. Cómo funciona en tiempo de ejecución](#6-cómo-funciona-en-tiempo-de-ejecución)
  - [7. Ubicación de los datos sincronizados](#7-ubicación-de-los-datos-sincronizados)
  - [8. Verificación del funcionamiento](#8-verificación-del-funcionamiento)
  - [9. Prueba manual de ejecución](#9-prueba-manual-de-ejecución)
  - [10. Desinstalación paso a paso](#10-desinstalación-paso-a-paso)
  - [11. Solución de problemas comunes](#11-solución-de-problemas-comunes)
  - [12. Notas de seguridad y comportamiento](#12-notas-de-seguridad-y-comportamiento)
  - [13. Renovaciones y mantenimiento](#13-renovaciones-y-mantenimiento)
  - [14. Referencias rápidas de comandos](#14-referencias-rápidas-de-comandos)

## 1. Visión General
USB Auto-Sync Service es una solución silenciosa para Windows que detecta automáticamente la conexión de unidades USB de almacenamiento masivo y copia su contenido a un repositorio local oculto. El sistema está diseñado para funcionar sin polling permanente, activándose únicamente mediante eventos del Programador de Tareas y ejecutándose en segundo plano como `NT AUTHORITY\SYSTEM`.

## 2. Requisitos Previos
- Windows 10/11 o Windows Server compatible.
- Permisos de administrador para instalar y desinstalar.
- PowerShell disponible en el sistema.
- `robocopy.exe` disponible (incluido en todas las ediciones modernas de Windows).

## 3. Estructura de archivos
La carpeta de trabajo contiene:
- `USB_Sync_Task.xml`: definición de la tarea programada basada en eventos.
- `sync_engine.ps1`: script que detecta unidades USB y ejecuta `robocopy`.
- `install.ps1`: script de instalación que copia archivos y registra la tarea.
- `uninstall.ps1`: script de desinstalación que elimina la tarea y la carpeta de instalación.
- `README.md`: descripción breve del proyecto.
- `USBSync_User_Manual.md`: este manual detallado.

## 4. Preparación
1. Abre PowerShell como Administrador.
2. Navega a la carpeta donde se encuentran los archivos, por ejemplo:

```powershell
cd h:\SCRIPTUSB
```

3. Verifica la existencia de los archivos:

```powershell
Get-ChildItem
```

Deberías ver `install.ps1`, `sync_engine.ps1`, `USB_Sync_Task.xml` y `uninstall.ps1`.

## 5. Instalación paso a paso
1. Ejecuta el script de instalación:

```powershell
.\install.ps1
```

2. El script realiza lo siguiente:
- Crea `C:\ProgramData\USBSync` si no existe.
- Copia `sync_engine.ps1` y `USB_Sync_Task.xml` al directorio de instalación.
- Registra la tarea programada `Infrastructure\USBSyncService` en el Programador de Tareas.
- Marca la carpeta como oculta y de sistema.

3. Comprueba que la tarea quedó registrada:

```powershell
Get-ScheduledTask -TaskName 'Infrastructure\USBSyncService'
```

Si retorna información de la tarea, la instalación fue exitosa.

## 6. Cómo funciona en tiempo de ejecución
1. Windows monitorea el canal de eventos `Microsoft-Windows-DriverFrameworks-UserMode/Operational`.
2. Cuando se detecta un evento con `EventID=2003` o `EventID=2101`, el Programador de Tareas activa la tarea.
3. La tarea ejecuta `powershell.exe` en modo oculto, usando el script `sync_engine.ps1`.
4. El script valida las unidades removibles (`DriveType = 2`) y crea un repositorio local único por cada volumen USB, basado en su número de serie.
5. Para cada unidad válida se lanza `robocopy` con parámetros de copia multihilo y modo respaldo.

## 7. Ubicación de los datos sincronizados
- El contenido se copia a:

```text
C:\ProgramData\USBSync\Storage\<Serial del volumen>\
```

- El directorio `C:\ProgramData\USBSync` está marcado como `Hidden` y `System`.
- El archivo de log se encuentra en:

```text
C:\ProgramData\USBSync\sync_log.txt
```

## 8. Verificación del funcionamiento
1. Inserta un dispositivo USB con archivos.
2. Si el evento es detectado, la tarea se ejecutará automáticamente.
3. Revisa el log:

```powershell
Get-Content 'C:\ProgramData\USBSync\sync_log.txt' -Tail 50
```

4. Verifica que la carpeta de destino correspondiente al serial haya sido creada.

## 9. Prueba manual de ejecución
Si deseas forzar una ejecución manual, puedes ejecutar el script directamente (aunque el diseño recomendado es que solo corra desde la tarea):

```powershell
C:\ProgramData\USBSync\sync_engine.ps1
```

Esto permite validar que el script y `robocopy` funcionan correctamente.

## 10. Desinstalación paso a paso
1. Abre PowerShell como Administrador.
2. Navega a `h:\SCRIPTUSB`.
3. Ejecuta:

```powershell
.\uninstall.ps1
```

4. El script hará:
- Eliminar la tarea programada `Infrastructure\USBSyncService`.
- Borrar `C:\ProgramData\USBSync` y su contenido.

5. Verifica que la tarea ya no exista:

```powershell
Get-ScheduledTask -TaskName 'Infrastructure\USBSyncService' -ErrorAction SilentlyContinue
```

Si no retorna nada, la tarea ha sido eliminada.

## 11. Solución de problemas comunes
- `No se detecta USB`:
  - Asegúrate de que el dispositivo sea de almacenamiento masivo y no solo un dispositivo multimedia.
  - Comprueba que Windows monta una letra de unidad.

- `Tarea no se dispara`:
  - Verifica en el Visor de eventos si hay eventos `2003` o `2101` en `Microsoft-Windows-DriverFrameworks-UserMode/Operational`.
  - Confirma que la tarea está habilitada y oculta.

- `Robocopy falla`:
  - Revisa `C:\ProgramData\USBSync\sync_log.txt`.
  - Comprueba permisos y la disponibilidad de la unidad USB.

- `Carpeta de destino no aparece`:
  - El repositorio puede estar oculto. Usa `Get-ChildItem -Force` para listarlo.
  - Verifica que el número de serie del volumen no sea `UNKNOWN_SERIAL`.

## 12. Notas de seguridad y comportamiento
- El servicio corre como `SYSTEM`, por lo que tiene privilegios elevados y puede copiar archivos con ACL restrictivas usando `/B`.
- No utiliza polling continuo: el consumo de recursos es mínimo mientras no haya USB conectado.
- El usuario no verá ventanas de consola porque la tarea se ejecuta con `-WindowStyle Hidden` y `CreateNoWindow = $true`.

## 13. Renovaciones y mantenimiento
- Si modificas `sync_engine.ps1`, vuelve a ejecutar `install.ps1` para copiar la versión actualizada en `C:\ProgramData\USBSync`.
- Si deseas cambiar el trigger del evento, ajusta `USB_Sync_Task.xml` y vuelve a registrar la tarea.

## 14. Referencias rápidas de comandos
- Instalar:
  ```powershell
  .\install.ps1
  ```
- Desinstalar:
  ```powershell
  .\uninstall.ps1
  ```
- Verificar tarea:
  ```powershell
  Get-ScheduledTask -TaskName 'Infrastructure\USBSyncService'
  ```
- Ver logs:
  ```powershell
  Get-Content 'C:\ProgramData\USBSync\sync_log.txt' -Tail 50
  ```
- Ejecutar el motor manualmente:
  ```powershell
  C:\ProgramData\USBSync\sync_engine.ps1
  ```
