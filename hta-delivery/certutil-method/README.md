# Certutil-Method HTA

Downloads a Base64-encoded payload with `certutil -urlcache`, decodes it with `certutil -decode`, and executes via `InstallUtil.exe /U`.

## Evasion profile

| Layer | Status |
|-------|--------|
| AMSI | Not applicable (JScript HTA) |
| Signature | Depends on payload — use AES-encrypted loader |
| Behavioral | `certutil` is a monitored LOLBin — use `self-decode-method/` if this is flagged |
| Network | HTTP download — visible in proxy logs |

## Usage

1. Base64-encode your compiled loader:
   ```batch
   certutil -encode loader.exe payload.b64
   ```
2. Host `payload.b64` on your HTTP server
3. Edit `loader.hta` and set `payloadUrl` to your server URL
4. Deliver the HTA to the target

## When to use

Use this method when you need a simple download-and-execute chain and certutil is not blocked. For better evasion, use `../self-decode-method/`.
