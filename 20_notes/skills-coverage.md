# Skills Coverage Tracker

**Tracks which skills have been exercised across all engagement kinds.**

Auto-maintained manually after closing each engagement. Run `export-summary.ps1`
to refresh `INDEX.md` with the "By Skill" section; update this file by hand when
you add or strengthen a skill entry.

---

## How to use

1. When you close an engagement, add or update the row for each skill practiced.
2. Link the engagement ID in the "Engagements" column.
3. Update the "Depth" rating honestly using the scale below.
4. The `skills[]` field in `03_findings` frontmatter feeds the automated index.

### Depth scale

| Rating | Meaning |
|--------|---------|
| `intro` | Encountered for the first time; read or followed a walkthrough |
| `practiced` | Applied independently at least once with some guidance |
| `solid` | Applied independently multiple times; can explain the technique |
| `strong` | Comfortable applying in novel contexts; could teach it |

---

## Offensive / Attack Skills

| Skill | Category | Depth | Engagements | Notes |
|-------|---------|-------|------------|-------|
| SQL injection (classic) | Web | -- | -- | |
| SQL injection (blind/time-based) | Web | -- | -- | |
| Cross-site scripting (XSS) | Web | -- | -- | |
| Local/remote file inclusion (LFI/RFI) | Web | -- | -- | |
| Server-side request forgery (SSRF) | Web | -- | -- | |
| Command injection | Web | -- | -- | |
| Directory traversal | Web | -- | -- | |
| Authentication bypass | Web | -- | -- | |
| JWT attacks | Web | -- | -- | |
| IDOR / access control bypass | Web | -- | -- | |
| XXE injection | Web | -- | -- | |
| Deserialization | Web | -- | -- | |
| Buffer overflow (Linux x86) | Pwn | -- | -- | |
| Buffer overflow (Windows) | Pwn | -- | -- | |
| Format string exploitation | Pwn | -- | -- | |
| Heap exploitation | Pwn | -- | -- | |
| ROP chains | Pwn | -- | -- | |
| Static reverse engineering (x86/x64) | Rev | -- | -- | |
| Dynamic reverse engineering (debugger) | Rev | -- | -- | |
| Unpacking / deobfuscation | Rev | -- | -- | |
| Cryptography analysis / breaking | Crypto | -- | -- | |
| Hash cracking (hashcat / John) | Crypto | -- | -- | |
| Encoding/decoding (base64, XOR, etc.) | Crypto | -- | -- | |
| Network enumeration (nmap) | Recon | -- | -- | |
| Web enumeration (gobuster/ferox) | Recon | -- | -- | |
| OSINT / passive recon | Recon | -- | -- | |
| LDAP / Active Directory enumeration | Recon | -- | -- | |
| SMB enumeration | Recon | -- | -- | |
| Privilege escalation (Linux) | Post-exploit | -- | -- | |
| Privilege escalation (Windows) | Post-exploit | -- | -- | |
| Lateral movement | Post-exploit | -- | -- | |
| Persistence (Windows) | Post-exploit | -- | -- | |
| Credential dumping | Post-exploit | -- | -- | |
| Pass the hash / pass the ticket | Post-exploit | -- | -- | |

---

## Malware Analysis Skills

| Skill | Category | Depth | Engagements | Notes |
|-------|---------|-------|------------|-------|
| PE static analysis (DIE/PEStudio/CFF) | Static | solid | sample_01 | NSIS installer |
| HxD hex inspection | Static | solid | sample_01 | |
| Entropy analysis | Static | solid | sample_01 | |
| NSIS extraction / script recovery | Static | intro | sample_01 | Not yet performed |
| UPX unpacking | Static | -- | -- | |
| Office macro analysis (olevba) | Static | -- | -- | |
| Script deobfuscation (PS1/VBS/JS) | Static | -- | -- | |
| Dynamic analysis with Procmon | Dynamic | practiced | sample_01 | Partial -- no Procmon CSV yet |
| Process tree analysis | Dynamic | practiced | sample_01 | Phone screenshot only |
| Network capture (Wireshark) | Dynamic | -- | -- | |
| YARA rule writing | Detection | -- | -- | |
| MITRE ATT&CK technique mapping | Framework | practiced | sample_01 | |
| IOC extraction and formatting | Intel | practiced | sample_01 | |

---

## Detection and Hunting Skills

| Skill | Category | Depth | Engagements | Notes |
|-------|---------|-------|------------|-------|
| Windows Event Log analysis | Detection | -- | -- | |
| Sysmon log analysis | Detection | -- | -- | |
| SIEM query writing (Splunk SPL) | Detection | -- | -- | |
| SIEM query writing (Elastic DSL) | Detection | -- | -- | |
| Sigma rule writing | Detection | -- | -- | |
| Threat hunting methodology | Hunt | -- | -- | |
| Timeline reconstruction | Forensics | -- | -- | |
| Log correlation | Forensics | -- | -- | |
| Network flow analysis | Forensics | -- | -- | |

---

## Lab and Platform Skills

| Skill | Category | Depth | Engagements | Notes |
|-------|---------|-------|------------|-------|
| Linux fundamentals | OS | -- | -- | |
| Windows fundamentals | OS | -- | -- | |
| Active Directory fundamentals | OS | -- | -- | |
| Networking fundamentals | Network | -- | -- | |
| Scripting (Bash) | Scripting | -- | -- | |
| Scripting (PowerShell) | Scripting | -- | -- | |
| Python scripting | Scripting | -- | -- | |
| Docker / containerization | Platform | -- | -- | |
| Git and version control | Tooling | solid | all | Used throughout repo |
| Report writing | Comms | solid | sample_01 | |

---

## Portfolio role lines

> One-sentence resume bullets generated from the strongest skills and engagements.
> Update after closing each significant engagement.

- Performed static and dynamic triage on a UPX-packed infostealer, mapping credential
  theft, persistence, and C2 beaconing to MITRE ATT&CK techniques using Procmon and
  Wireshark in an isolated Windows VM.
  *(based on sample_01)*

---

*See also: [`20_notes/MITRE-coverage.md`](./MITRE-coverage.md) for file-kind technique tracking.*  
*See also: [`INDEX.md`](../INDEX.md) "By Skill" section (auto-generated).*
