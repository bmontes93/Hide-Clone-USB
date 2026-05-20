@echo off
title Desinstalador de USB Auto-Sync Service
setlocal EnableDelayedExpansion

:: 1. Verificar privilegios de administrador
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :isAdmin
) else (
    goto :elevate
)

:elevate
:: Crear un script temporal en VBScript para solicitar elevacion
set "vbsTemp=%temp%\uac_elevate.vbs"
echo Set UAC = CreateObject^("Shell.Application"^) > "%vbsTemp%"
echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %*", "", "runas", 1 >> "%vbsTemp%"
"%vbsTemp%"
del "%vbsTemp%"
exit /B

:isAdmin
:: 2. Ya somos administrador. Ejecutamos el desinstalador ocultando la politica de restriccion.
echo [-] Ejecutando desinstalador de USB Auto-Sync Service con privilegios elevados...
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "uninstall.ps1"
if %errorLevel% == 0 (
    echo.
    echo [-] Desinstalacion finalizada correctamente.
) else (
    echo.
    echo [!] Hubo un error durante la desinstalacion.
)
pause
exit /B
