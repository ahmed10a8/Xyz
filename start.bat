@echo off
setlocal EnableDelayedExpansion

del /f "C:\Users\Public\Desktop\Epic Games Launcher.lnk" > errormsg.txt 2>&1

net config server /srvcomment:"Windows Server By admin" > errormsg.txt 2>&1

REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /V EnableAutoTray /T REG_DWORD /D 0 /F > errormsg.txt 2>&1

net user admin 123123aA@ /add >nul
net localgroup administrators admin /add >nul
net user admin /active:yes >nul
net user installer /delete >nul 2>&1

diskperf -Y >nul

sc config Audiosrv start= auto >nul
sc start audiosrv >nul

ICACLS C:\Windows\Temp /grant admin:F >nul
ICACLS C:\Windows\installer /grant admin:F >nul

echo Successfully installed! If RDP is dead, rebuild again.
echo.
echo Waiting for NGROK tunnel...
echo.

set NGROK_URL=

for /l %%i in (1,1,30) do (
    curl.exe -s http://127.0.0.1:4040/api/tunnels > ngrok.json 2>nul

    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $j = Get-Content 'ngrok.json' -Raw | ConvertFrom-Json; if ($j.tunnels.Count -gt 0) { $j.tunnels[0].public_url } } catch { }" > ngrok_url.txt 2>nul

    set /p NGROK_URL=<ngrok_url.txt 2>nul

    if not "!NGROK_URL!"=="" goto showlink4040

    curl.exe -s http://127.0.0.1:8080/api/tunnels > ngrok.json 2>nul

    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $j = Get-Content 'ngrok.json' -Raw | ConvertFrom-Json; if ($j.tunnels.Count -gt 0) { $j.tunnels[0].public_url } } catch { }" > ngrok_url.txt 2>nul

    set /p NGROK_URL=<ngrok_url.txt 2>nul

    if not "!NGROK_URL!"=="" goto showlink8080

    echo NGROK tunnel not ready yet... Try %%i of 30
    timeout /t 2 >nul
)

echo.
echo Failed to retrieve NGROK URL.
echo Make sure ngrok.exe is running and your authtoken is correct.
echo.
goto logininfo

:showlink4040
echo.
echo ========================================
echo NGROK URL:
type ngrok_url.txt
echo ========================================
echo.
goto logininfo

:showlink8080
echo.
echo ========================================
echo NGROK URL:
type ngrok_url.txt
echo ========================================
echo.
goto logininfo

:logininfo
echo Username: admin
echo Password: 123123aA@
echo You can login now!

ping -n 10 127.0.0.1 >nul

endlocal
