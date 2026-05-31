@echo off
setlocal EnableDelayedExpansion

title Temporary Windows VPS Test Session

set ADMIN_USER=admin
set ADMIN_PASS=123123aA@
set NGROK_JSON=ngrok.json
set NGROK_URL_FILE=ngrok_url.txt
set CONNECTION_FILE=connection.txt

echo Preparing temporary test session...
echo.

REM Clean old output files
if exist "%NGROK_JSON%" del /f "%NGROK_JSON%" >nul 2>&1
if exist "%NGROK_URL_FILE%" del /f "%NGROK_URL_FILE%" >nul 2>&1
if exist "%CONNECTION_FILE%" del /f "%CONNECTION_FILE%" >nul 2>&1
if exist rdp_address.txt del /f rdp_address.txt >nul 2>&1
if exist errormsg.txt del /f errormsg.txt >nul 2>&1

REM Optional small cleanup
del /f "C:\Users\Public\Desktop\Epic Games Launcher.lnk" > errormsg.txt 2>&1

REM Basic Windows settings
net config server /srvcomment:"Windows Server By admin" > errormsg.txt 2>&1

REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /V EnableAutoTray /T REG_DWORD /D 0 /F >nul 2>&1

REM Create or update admin user with fixed password
net user "%ADMIN_USER%" >nul 2>&1

if errorlevel 1 (
    net user "%ADMIN_USER%" "%ADMIN_PASS%" /add /active:yes >nul 2>&1
) else (
    net user "%ADMIN_USER%" "%ADMIN_PASS%" /active:yes >nul 2>&1
)

REM Full administrator permissions
net localgroup administrators "%ADMIN_USER%" /add >nul 2>&1
net localgroup "Remote Desktop Users" "%ADMIN_USER%" /add >nul 2>&1

REM Keep password from expiring
wmic useraccount where "name='%ADMIN_USER%'" set PasswordExpires=false >nul 2>&1
net accounts /maxpwage:unlimited >nul 2>&1

REM Same old behavior
net user installer /delete >nul 2>&1

REM Enable Remote Desktop
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /V fDenyTSConnections /T REG_DWORD /D 0 /F >nul 2>&1
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /V UserAuthentication /T REG_DWORD /D 0 /F >nul 2>&1

netsh advfirewall firewall set rule group="remote desktop" new enable=Yes >nul 2>&1

REM Enable audio service
sc config Audiosrv start= auto >nul 2>&1
sc start Audiosrv >nul 2>&1

REM Enable disk performance counters
diskperf -Y >nul 2>&1

REM Same permissions you had before
ICACLS C:\Windows\Temp /grant "%ADMIN_USER%":F >nul 2>&1
ICACLS C:\Windows\installer /grant "%ADMIN_USER%":F >nul 2>&1

REM Extra practical workspace permissions
if not exist "C:\TestWorkspace" mkdir "C:\TestWorkspace" >nul 2>&1
if not exist "C:\TestWorkspace\Projects" mkdir "C:\TestWorkspace\Projects" >nul 2>&1
if not exist "C:\TestWorkspace\Downloads" mkdir "C:\TestWorkspace\Downloads" >nul 2>&1
if not exist "C:\TestWorkspace\Temp" mkdir "C:\TestWorkspace\Temp" >nul 2>&1

icacls "C:\TestWorkspace" /inheritance:e >nul 2>&1
icacls "C:\TestWorkspace" /grant "%ADMIN_USER%:(OI)(CI)F" /T /C >nul 2>&1
icacls "C:\Users\Public\Desktop" /grant "%ADMIN_USER%:(OI)(CI)F" /T /C >nul 2>&1
icacls "C:\Users\Public\Documents" /grant "%ADMIN_USER%:(OI)(CI)F" /T /C >nul 2>&1

set TEMP=C:\TestWorkspace\Temp
set TMP=C:\TestWorkspace\Temp

echo Windows session prepared.
echo.
echo Waiting for NGROK tunnel...
echo.

set NGROK_URL=
set RDP_ADDRESS=

for /l %%i in (1,1,45) do (
    REM Try default ngrok API port 4040
    curl.exe -s http://127.0.0.1:4040/api/tunnels > "%NGROK_JSON%" 2>nul

    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $j = Get-Content '%NGROK_JSON%' -Raw | ConvertFrom-Json; if ($j.tunnels.Count -gt 0) { $j.tunnels[0].public_url } } catch { }" > "%NGROK_URL_FILE%" 2>nul

    set /p NGROK_URL=<%NGROK_URL_FILE% 2>nul

    if not "!NGROK_URL!"=="" goto got_ngrok

    REM Try alternative API port 8080
    curl.exe -s http://127.0.0.1:8080/api/tunnels > "%NGROK_JSON%" 2>nul

    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $j = Get-Content '%NGROK_JSON%' -Raw | ConvertFrom-Json; if ($j.tunnels.Count -gt 0) { $j.tunnels[0].public_url } } catch { }" > "%NGROK_URL_FILE%" 2>nul

    set /p NGROK_URL=<%NGROK_URL_FILE% 2>nul

    if not "!NGROK_URL!"=="" goto got_ngrok

    echo NGROK tunnel not ready yet... Try %%i of 45
    timeout /t 2 >nul
)

echo.
echo Failed to retrieve NGROK URL.
echo Make sure ngrok.exe is running and your authtoken is correct.
echo.

goto show_login

:got_ngrok
powershell -NoProfile -ExecutionPolicy Bypass -Command "$u=Get-Content '%NGROK_URL_FILE%' -Raw; $u=$u.Trim().Replace('tcp://','').Replace('http://','').Replace('https://',''); Set-Content -Path rdp_address.txt -Value $u" >nul 2>&1

set /p RDP_ADDRESS=<rdp_address.txt

echo.
echo ========================================
echo NGROK URL:
type "%NGROK_URL_FILE%"
echo.
echo RDP ADDRESS:
type rdp_address.txt
echo ========================================
echo.

:show_login
echo Username: %ADMIN_USER%
echo Password: %ADMIN_PASS%
echo.

REM Save connection details
echo NGROK URL: > "%CONNECTION_FILE%"
if exist "%NGROK_URL_FILE%" type "%NGROK_URL_FILE%" >> "%CONNECTION_FILE%"
echo. >> "%CONNECTION_FILE%"
echo RDP ADDRESS: >> "%CONNECTION_FILE%"
if exist rdp_address.txt type rdp_address.txt >> "%CONNECTION_FILE%"
echo. >> "%CONNECTION_FILE%"
echo Username: %ADMIN_USER% >> "%CONNECTION_FILE%"
echo Password: %ADMIN_PASS% >> "%CONNECTION_FILE%"

echo Connection details saved to:
echo %CONNECTION_FILE%
echo.

echo You can login now.
echo.

REM Optional system info
echo System Info:
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Type" /C:"Total Physical Memory"
echo.

echo CPU:
wmic cpu get name
echo.

echo Disk:
wmic logicaldisk get caption,freespace,size
echo.

:end
ping -n 10 127.0.0.1 >nul

endlocal
