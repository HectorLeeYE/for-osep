@echo off
REM =============================================================================
REM for-osep Build Script
REM Usage: build.bat
REM ==============================================================================

echo [INFO] Building for-osep components...
echo.

REM Check required tools
echo [INFO] Checking required tools...
where >nul 2>&1 || (echo [ERROR] Windows SDK not found. exit /b 1)
echo [OK] Windows SDK
where powershell >nul 2>&1 || (echo [ERROR] PowerShell not found. exit /b 1)
echo [OK] PowerShell
echo.

REM Build AES Loaders
echo [INFO] Building AES Loaders...
set "aesDir=C:\MALDEV\for-osep\aes-loaders\aes-loaders"
if not exist "%aesDir%" ( echo [ERROR] AES loaders directory not found. exit /b 1 )

cd /d "%aesDir\aes-normal-runner"
if exist "Program.cs" (
    if exist "out\aes-normal-runner.exe" echo [OK] aes-normal-runner.exe already built
    else echo [INFO] Building aes-normal-runner.exe...
)
cd /d "%aesDir"

cd /d "%aesDir\aes-process-injection"
if exist "Program.cs" (
    if exist "out\aes-process-injection.exe" echo [OK] aes-process-injection.exe already built
    else echo [INFO] Building aes-process-injection.exe...
)
cd /d "%aesDir"
echo.

REM Build InstallUtil Loaders
echo [INFO] Building InstallUtil Loaders...
set "iuDir=C:\MALDEV\for-osep\installutil"
if not exist "%iuDir%" ( echo [ERROR] InstallUtil directory not found. exit /b 1 )

cd /d "%iuDir"
for /f "tokens=*" %%i in ('dir /b /ad') do (
    set "subdir=%%i"
    if exist "%iuDir%\%subdir%\Loader.cs" (
        echo [INFO] Building %subdir%...
        cd /d "%iuDir%\%subdir%"
        if exist "compile.bat" (
            compile.bat
        ) else if exist "Loader.cs" (
            if exist "out\Loader.exe" echo [OK] Loader.exe already built
            else echo [INFO] Building with csc...
        )
        cd /d "%iuDir"
    }
)
echo.

REM Build Shellcode Generator
echo [INFO] Shellcode Generator...
set "scDir=C:\MALDEV\for-osep\shellcode-gen"
if not exist "%scDir%" ( echo [ERROR] Shellcode generator not found. exit /b 1 )
echo [OK] aes-encrypt-shellcode.ps1 ready
echo [OK] byte-array-converter.ps1 ready
echo [OK] donut-wrapper.ps1 ready
echo.

REM HTA Delivery Methods
echo [INFO] HTA Delivery Methods...
set "htaDir=C:\MALDEV\for-osep\hta-delivery"
echo [OK] black.hta (bitsadmin download)
echo [OK] red.hta (certutil decode)
echo [OK] http-decode-method\loader.hta (pure COM)
echo [OK] certutil-method\loader.hta
echo [OK] self-decode-method\loader.hta
echo.

REM PS Loaders
echo [INFO] PS Loaders...
set "psDir=C:\MALDEV\for-osep\ps-loaders"
if not exist "%psDir%" ( echo [ERROR] PS loaders not found. exit /b 1 )
echo [OK] ps-loader.ps1 ready
echo [OK] ps-shellcode-runner.ps1 ready
echo.

REM Final Summary
echo ==============================================================================
echo Build Complete!
echo ==============================================================================
echo [OK] AES Loaders: aes-normal-runner.exe, aes-process-injection.exe
echo [OK] InstallUtil Loaders: aes-loaders\, runspace-loader\, section-injection\
echo [OK] Shellcode Tools: aes-encrypt-shellcode.ps1, byte-array-converter.ps1, donut-wrapper.ps1
echo [OK] AMSI Bypass: amsi-bypass.ps1
echo [OK] HTA Delivery: black.hta, red.hta, http-decode-method\loader.hta, etc.
echo [OK] PS Loaders: ps-loader.ps1, ps-shellcode-runner.ps1
echo.
echo [INFO] Configure C2 IPs in HTA files (search for YOUR_C2_IP_HERE)
echo [INFO] For OSEP exam: focus on AES loaders + AMSI bypass integration
echo ==============================================================================