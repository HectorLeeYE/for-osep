# verify_crypto.ps1
# Decrypts an aes_data.cs file with the same AES-256-CBC/PKCS7 parameters the
# section-injection Loader.cs uses, and byte-compares the result to a raw shellcode file.
param(
    [Parameter(Mandatory=$true)][string]$AesData,
    [Parameter(Mandatory=$true)][string]$Raw
)

function Get-ByteArray([string]$text, [string]$name) {
    $m = [regex]::Match($text, "private static readonly byte\[\] $name = new byte\[\d+\] \{ ([^}]*)\};")
    if (-not $m.Success) { throw "Could not parse $name" }
    $vals = $m.Groups[1].Value.Split(',') | Where-Object { $_.Trim().Length -gt 0 }
    $bytes = New-Object byte[] $vals.Count
    for ($i = 0; $i -lt $vals.Count; $i++) {
        $bytes[$i] = [Convert]::ToByte($vals[$i].Trim().Substring(2), 16)
    }
    return ,$bytes
}

$content = Get-Content -LiteralPath $AesData -Raw
$key = Get-ByteArray $content 'AesKey'
$iv  = Get-ByteArray $content 'AesIV'
$enc = Get-ByteArray $content 'EncryptedShellcode'

$ae = [System.Security.Cryptography.Aes]::Create()
$ae.KeySize = 256
$ae.Mode    = [System.Security.Cryptography.CipherMode]::CBC
$ae.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$ae.Key = $key
$ae.IV  = $iv
$dec = $ae.CreateDecryptor()
$plain = $dec.TransformFinalBlock($enc, 0, $enc.Length)

$orig = [IO.File]::ReadAllBytes($Raw)

Write-Host ("AES data   : {0}" -f $AesData)
Write-Host ("Raw shellcode: {0}" -f $Raw)
Write-Host ("  key        : {0} bytes" -f $key.Length)
Write-Host ("  iv         : {0} bytes" -f $iv.Length)
Write-Host ("  ciphertext : {0} bytes" -f $enc.Length)
Write-Host ("  decrypted  : {0} bytes" -f $plain.Length)
Write-Host ("  original   : {0} bytes" -f $orig.Length)

$match = ($plain.Length -eq $orig.Length)
if ($match) {
    for ($i = 0; $i -lt $orig.Length; $i++) {
        if ($plain[$i] -ne $orig[$i]) { $match = $false; Write-Host ("  first diff at offset {0}" -f $i); break }
    }
}
if ($match) { Write-Host "  RESULT: MATCH - decryption reproduces original shellcode exactly" -ForegroundColor Green }
else        { Write-Host "  RESULT: MISMATCH" -ForegroundColor Red }
