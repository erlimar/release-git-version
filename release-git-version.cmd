:: Copyright (c) Erliimar Silva Campos. All rights reserved.
:: Licensed under the Apache License, Version 2.0. More license information in LICENSE.txt.

@echo off

set PS=%~dpn0.ps1

where powershell >nul 2>&1
if "%ERRORLEVEL%" neq "0"; goto :requirepowershell

powershell -version 2 -c "if($psversiontable.psversion.major -ge 2){exit(0)}else{exit(1)}" >nul 2>&1
if "%ERRORLEVEL%" neq "0"; goto :requirepowershell2

powershell -NoProfile -ExecutionPolicy unrestricted -File %PS% %*

goto :finish

:requirepowershell
echo Requires PowerShell ^>= 2.0
goto :error

:requirepowershell2
echo Requires PowerShell ^>= 2.0...
goto :error

:error
endlocal
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:finish
endlocal
exit /b %ERRORLEVEL%
