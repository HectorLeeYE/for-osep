@echo off
REM =============================================================================
REM Compile the InstallUtil runspace loader with C#-native AMSI bypass
REM
REM Prerequisites:
REM   - .NET Framework 4.x installed (ships with Windows 10/11)
REM   - PowerShell installed (provides System.Management.Automation.dll in GAC)
REM   - Loader.cs and AmsiBypass.cs in the same directory
REM
REM Output: loader.exe
REM =============================================================================

REM Find System.Management.Automation.dll in the GAC
set "SMA_PATH="
for /f "delims=" %%F in ('dir /s /b "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\System.Management.Automation.dll" 2^>nul') do (
    if not defined SMA_PATH set "SMA_PATH=%%F"
)

if not defined SMA_PATH (
    echo [!] Could not find System.Management.Automation.dll in GAC
    echo [!] Is PowerShell installed on this system?
    exit /b 1
)

echo [+] Found SMA: %SMA_PATH%

C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe ^
  /target:exe ^
  /platform:x64 ^
  /optimize+ ^
  /out:loader.exe ^
  /reference:System.Configuration.Install.dll ^
  /reference:"%SMA_PATH%" ^
  Loader.cs AmsiBypass.cs

if %ERRORLEVEL% EQU 0 (
    echo [+] Build succeeded: loader.exe
) else (
    echo [!] Build failed - check error messages above
)