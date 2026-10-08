@echo off
REM =============================================================================
REM Compile the InstallUtil runspace loader with C#-native AMSI bypass
REM
REM Prerequisites:
REM   - .NET Framework 4.x installed (ships with Windows 10/11)
REM   - Loader.cs and AmsiBypass.cs in the same directory
REM
REM Output: loader.exe
REM =============================================================================

C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe ^
  /target:exe ^
  /platform:x64 ^
  /optimize+ ^
  /out:loader.exe ^
  /reference:System.Configuration.Install.dll ^
  /reference:System.Management.Automation.dll ^
  Loader.cs AmsiBypass.cs

if %ERRORLEVEL% EQU 0 (
    echo [+] Build succeeded: loader.exe
) else (
    echo [!] Build failed — check error messages above
)