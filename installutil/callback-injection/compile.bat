@echo off
REM =============================================================================
REM Compile the InstallUtil callback-injection loader
REM
REM Prerequisites:
REM   - .NET Framework 4.x installed (ships with Windows 10/11)
REM   - Loader.cs in the same directory with AES arrays filled in
REM
REM Output: loader.exe
REM =============================================================================

C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe ^
  /target:exe ^
  /platform:x64 ^
  /optimize+ ^
  /out:loader.exe ^
  /reference:System.Configuration.Install.dll ^
  Loader.cs

if %ERRORLEVEL% EQU 0 (
    echo [+] Build succeeded: loader.exe
) else (
    echo [!] Build failed — check error messages above
)