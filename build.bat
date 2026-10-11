@echo off
setlocal enabledelayedexpansion
REM =============================================================================
REM for-osep Build Script
REM Usage: build.bat
REM
REM Compiles the C# InstallUtil loaders (section-injection, callback-injection,
REM runspace-loader) and reports the status of the shellcode-generation and
REM delivery tooling.
REM
REM NOTE: the aes-loaders/* runners are TEMPLATES. Encrypt your shellcode and
REM patch the `buf` array first (see aes-loaders/README.md and
REM aes-loaders/aes-shellcode-encryption/encrypt-buf.ps1), then compile with:
REM   csc /target:exe /platform:x64 /optimize+ /out:Runner.exe <runner>.cs
REM =============================================================================

set "ROOT=%~dp0"
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

echo [INFO] for-osep build
echo.

echo [INFO] Checking required tools...
if not exist "%CSC%" ( echo [ERROR] csc.exe not found at %CSC% & exit /b 1 )
echo [OK] csc.exe
where powershell >nul 2>&1 || ( echo [ERROR] PowerShell not found. & exit /b 1 )
echo [OK] PowerShell
echo.

echo [INFO] Building InstallUtil loaders...
for /d %%D in ("%ROOT%installutil\*") do (
    if exist "%%D\compile.bat" (
        echo [INFO] Building %%~nxD ...
        pushd "%%D"
        call compile.bat
        popd
        if exist "%%D\loader.exe" ( echo [OK] %%~nxD\loader.exe ) else ( echo [!] %%~nxD\loader.exe was not produced )
    )
)
echo.

echo [INFO] Shellcode generation tools (shellcode-gen):
if exist "%ROOT%shellcode-gen\donut-wrapper.ps1"         echo [OK] donut-wrapper.ps1
if exist "%ROOT%shellcode-gen\aes-encrypt-shellcode.ps1" echo [OK] aes-encrypt-shellcode.ps1
if exist "%ROOT%shellcode-gen\byte-array-converter.ps1"  echo [OK] byte-array-converter.ps1
if exist "%ROOT%shellcode-gen\donut.exe"                 echo [OK] donut.exe
echo.

echo [INFO] AES loader tooling (aes-loaders):
if exist "%ROOT%aes-loaders\aes-shellcode-encryption\encrypt-buf.ps1" echo [OK] aes-shellcode-encryption\encrypt-buf.ps1
if exist "%ROOT%aes-integrate-loader.ps1"                            echo [OK] aes-integrate-loader.ps1
echo [INFO] aes-loaders runners are templates - patch 'buf' then compile with csc (see file header).
echo.

echo [INFO] Delivery / post-exploitation tooling:
if exist "%ROOT%hta-delivery\http-decode-method\loader.hta" echo [OK] hta-delivery\http-decode-method\loader.hta
if exist "%ROOT%ps-loaders\ps-loader.ps1"                   echo [OK] ps-loaders\ps-loader.ps1
if exist "%ROOT%ps-loaders\ps-shellcode-runner.ps1"         echo [OK] ps-loaders\ps-shellcode-runner.ps1
if exist "%ROOT%uac-bypass\uac-bypass.ps1"                  echo [OK] uac-bypass\uac-bypass.ps1
if exist "%ROOT%amsi-bypass\amsi-bypass.ps1"                echo [OK] amsi-bypass\amsi-bypass.ps1
echo.

echo ==============================================================================
echo Build complete.
echo ==============================================================================
endlocal
