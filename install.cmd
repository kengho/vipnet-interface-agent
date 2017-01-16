@echo off
echo.
echo Welcome to ViPNet Administrator Post Tool v0.2!
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
  goto :end
)

:master

@rem check if all needed files are present
@rem http://stackoverflow.com/questions/3827567/how-to-get-the-path-of-the-batch-script-in-windows
set PowershellScriptInstaller=%~dp0vipnet_administrator_post.ps1
if not exist "%PowershellScriptInstaller%" (
  echo Unable to find "%PowershellScriptInstaller%", please check archive.
  pause
  goto :end
)

set LocalScriptDir=C:\vipnet_administrator_post
set /p LocalScriptDir="Enter script installation directory [%LocalScriptDir%] : "
if not exist %LocalScriptDir% (
  echo %LocalScriptDir% don't exists, creating...
  mkdir %LocalScriptDir%
)
set IniFilePath=%LocalScriptDir%\vipnet_administrator_post.ini
echo [settings]>%IniFilePath%

set PowershellScriptOutput=%LocalScriptDir%\vipnet_administrator_post.ps1
copy "%PowershellScriptInstaller%" "%PowershellScriptOutput%" /Y >nul 2>&1

set Uninstaller=%~dp0uninstall.cmd
set UninstallerOutput=%LocalScriptDir%\uninstall.cmd
copy "%Uninstaller%" "%UninstallerOutput%" /Y >nul 2>&1

@rem http://stackoverflow.com/questions/1802127/how-to-run-a-powershell-script-without-displaying-a-window
set PsrunInstaller=%~dp0PSRun.exe
set PsrunOutput=%LocalScriptDir%\PSRun.exe
copy "%PsrunInstaller%" "%PsrunOutput%" /Y >nul 2>&1

set CurlDirPath=%LocalScriptDir%\curl
set CurlPath=%CurlDirPath%\curl-7.47.1-win32-mingw\bin\curl.exe
set CurlPathUnchanged=%CurlPath%
set CurlInstallerPath=%~dp0curl
set /p CurlPath="Enter full path to curl.exe (if none, copies curl to %LocalScriptDir%) [] : "
echo CurlPath=%CurlPath%>>%IniFilePath%
if %CurlPath% EQU %CurlPathUnchanged% (
  xcopy "%CurlInstallerPath%" "%CurlDirPath%" /I /E /C /Y
)

:token
set WebAuthToken=
set /p WebAuthToken="Enter web token (vipnet_administrator_post_TOKEN) [] : "
if not defined WebAuthToken (
  echo Token required.
  goto :token
)
echo WebAuthToken=%WebAuthToken%>>%IniFilePath%

:path
set WebPathNodename=
set /p WebPathNodename="Enter web path [] : "
if not defined WebPathNodename (
  echo Web path required.
  goto :path
)
echo WebPathNodename=%WebPathNodename%>>%IniFilePath%

@rem other settings
set NCCLogLastLineReadNumberPath=%LocalScriptDir%\ncc_log_last_line_read_number
echo NCCLogLastLineReadNumberPath=%NCCLogLastLineReadNumberPath%>>%IniFilePath%
(echo 0)>%NCCLogLastLineReadNumberPath%

echo First run. Posting nodename.doc.
for /f "delims=" %%i in ('powershell.exe %PowershellScriptOutput% -FirstRun true') do set response=%%i
if "%response%" equ "ok" (
	echo Success.
) else (
	echo Failure. Response: "%response%".
	echo Data is copied, but sceduled task is not created.
	goto :end
)

:ending
@rem allow to run powershell script
@rem http://superuser.com/questions/616106/set-executionpolicy-using-batch-file-powershell-script
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList 'Set-ExecutionPolicy RemoteSigned -Force' -Verb RunAs}"

set TastName=ViPNet Administrator Post
schtasks /delete /f /tn "%TastName%" >nul 2>&1
schtasks /create /tn "%TastName%" /tr "%PsrunOutput% %PowershellScriptOutput%" /sc minute /mo 1 >nul 2>&1
echo Task "%TastName%" scheduled every 1 min. You can change it manually using "taskschd.msc /s".
echo You can delete temporarily files.

:end
pause
