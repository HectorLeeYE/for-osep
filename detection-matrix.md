# Detection Matrix

Maps each tool in this repository to the detection layers it addresses. Use this to understand which tool to deploy against which defensive control.

| Tool | AMSI | Signature | Behavioral | Memory | Network |
|------|------|-----------|------------|--------|---------|
| `installutil/section-injection` | ❌ | ✅ (AES) | ⚠️ Section chain | ✅ (RW→RX) | ❌ |
| `installutil/callback-injection` | ❌ | ✅ (AES) | ✅ (no CreateThread) | ✅ (RW→RX) | ❌ |
| `installutil/runspace-loader` | ✅ (C# bypass) | ⚠️ | ⚠️ | N/A | ⚠️ |
| `aes-loaders/aes-process-injection` | ❌ | ⚠️ | ❌ (RWX) | ⚠️ | ❌ |
| `aes-loaders/aes-process-hollowing` | ❌ | ⚠️ | ⚠️ (no CreateThread) | ⚠️ (RWX during hollow) | ❌ |
| `aes-loaders/aes-normal-runner` | ❌ | ⚠️ | ❌ (RWX) | ❌ (RWX) | ❌ |
| `aes-loaders/aes-av-evasion` | ❌ | ⚠️ | ⚠️ (sandbox checks) | ❌ (RWX) | ❌ |
| `word-macro/installutil-applocker-bypass` | ❌ (PS IEX) | ❌ | ❌ | ❌ | ⚠️ (HTTP download) |
| `word-macro/xor-shellcode-runner` | ❌ | ⚠️ (3-byte XOR) | ⚠️ (W^X) | ⚠️ | ❌ |
| `word-macro/caesar-cipher` | ❌ | ❌ (Caesar +2) | ⚠️ | ⚠️ | ❌ |
| `hta-delivery/black.hta` | ❌ | ❌ | ❌ (bitsadmin + certutil) | N/A | ❌ (HTTP download) |
| `hta-delivery/self-decode-method` | ❌ | ✅ (embedded payload) | ⚠️ (ADODB.Stream) | N/A | ❌ |
| `hta-delivery/certutil-method` | ❌ | ⚠️ | ❌ (certutil) | N/A | ❌ (HTTP download) |
| `ps-loaders/ps-loader.ps1` | ✅ (AMSI+ETW patch) | ❌ | ❌ | ❌ | ⚠️ (HTTP download) |
| `ps-loaders/ps-shellcode-runner.ps1` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `amsi-bypass/amsi-bypass.ps1` | ✅ | ❌ (signatured) | N/A | N/A | N/A |
| `uac-bypass/uac-bypass.ps1` | ✅ | ⚠️ (char arrays) | ⚠️ (fodhelper) | N/A | N/A |

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Addressed — the tool includes specific countermeasures for this detection layer |
| ⚠️ | Partial — some mitigation present, but not comprehensive |
| ❌ | Not addressed — this detection layer will likely trigger |
| N/A | Not applicable — this tool doesn't interact with that layer |

## Detection Layer Definitions

| Layer | What it detects | Key indicators |
|-------|----------------|----------------|
| **AMSI** | Malicious PowerShell/VBS/JScript content scanning | `AmsiScanBuffer` hits, script content patterns |
| **Signature** | Known-bad file hashes and byte patterns | SHA256 matches, YARA rules, static byte sequences |
| **Behavioral** | Suspicious API call sequences and process行为 | `VirtualAllocEx`+`WriteProcessMemory`+`CreateRemoteThread`, `NtCreateSection` chains, LOLBin usage |
| **Memory** | In-memory scanning of process address spaces | RWX regions, unbacked executable pages, decrypted shellcode patterns |
| **Network** | C2 traffic patterns and connections | HTTP beacons, DNS tunneling, TLS certificate anomalies |

## Recommended Tool Selection

| Scenario | Recommended tool |
|----------|-----------------|
| Initial access, Defender active, no PowerShell allowed | `installutil/section-injection` |
| CreateRemoteThread flagged, need alternative execution | `installutil/callback-injection` |
| Need PowerShell post-exploitation with AMSI bypass | `installutil/runspace-loader` |
| No Office, no PowerShell, need HTA delivery | `hta-delivery/self-decode-method` |
| AppLocker bypass with Word macro | `word-macro/installutil-applocker-bypass` |
| Lab/testing, maximum compatibility | `aes-loaders/aes-normal-runner` |
