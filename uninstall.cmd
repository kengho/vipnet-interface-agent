@echo off
echo.
echo Uninstalling ViPNet Administrator Post Tool v0.2!...
echo.

@rem http://stackoverflow.com/questions/4051883/batch-script-how-to-check-for-admin-rights
goto check_permissions

:check_permissions

echo Administrative permissions required. Detecting permissions...
net session >nul 2>&1
if %errorLevel% == 0 (
  echo Success: Administrative permissions confirmed.
  echo.
  goto :master
) else (
  echo Failure: Current permissions inadequate. Exiting.
  pause
  goto :end
)

:master

schtasks /delete /f /tn "ViPNet Administrator Post Log" >nul 2>&1
echo Scheduled task deleted. You may remove remaining files manually.

@rem return ExecutionPolicy to normal
@rem PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList 'Set-ExecutionPolicy AllSigned -Force' -Verb RunAs}"

pause
