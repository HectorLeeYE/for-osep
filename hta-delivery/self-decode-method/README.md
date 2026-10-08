# Self-Decode HTA

HTA that embeds the Base64-encoded payload directly — no downloads, no bitsadmin, no certutil. Decodes via VBScript using `MSXML2.DOMDocument` and writes to disk with `ADODB.Stream`, then executes via `InstallUtil.exe /U`.

## Evasion profile

| Layer | Status |
|-------|--------|
| AMSI | Not applicable (VBScript HTA, no PowerShell) |
| Signature | Payload is embedded — no network download signature |
| Behavioral | `ADODB.Stream` file write is less monitored than certutil/bitsadmin |
| Network | None — payload is embedded in the HTA file |

## Usage

1. Compile your loader (see `../../installutil/section-injection/`)
2. Base64-encode the compiled EXE:
   ```batch
   certutil -encode loader.exe loader.b64
   ```
3. Open `loader.hta` and replace the `b64` variable value with the contents of `loader.b64`
4. Deliver the HTA to the target (email attachment, USB drop, etc.)

## How it works

```
1. HTA loads → VBScript reads embedded Base64 string
2. MSXML2.DOMDocument decodes Base64 → byte array
3. ADODB.Stream writes bytes to %TEMP%\svc.exe
4. WScript.Shell runs: InstallUtil.exe /U %TEMP%\svc.exe
5. HTA window closes
```

## Limitations

- The HTA file size equals the Base64-encoded payload size (~1.33x the EXE size)
- Large payloads may trigger email attachment scanners by size
- `mshta.exe` itself is monitored by some EDRs — the HTA application tag helps blend in
