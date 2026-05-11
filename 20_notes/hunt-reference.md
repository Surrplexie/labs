# Threat Hunt Reference

**Quick reference for data sources, event IDs, queries, and methodology used in hunt engagements.**

For malware analysis tooling see [`tooling-reference.md`](./tooling-reference.md).
For CTF tooling see [`ctf-tooling-reference.md`](./ctf-tooling-reference.md).

---

## Hunt methodology

### PEAK / scientific method loop

1. **Hypothesis** -- One falsifiable statement: "Attacker used X technique to achieve Y in Z."
2. **Scope** -- Which data sources, time range, systems, out of scope.
3. **Collect** -- Pull relevant events/logs without filtering yet.
4. **Analyse** -- Look for deviations from baseline: rare parent-child, odd times, unusual paths.
5. **Pivot** -- Every finding becomes a new hypothesis; follow chains.
6. **Conclude** -- Document confirmed detections, false positives, confidence level, recommendations.

**Good hypothesis traits:**
- Based on a threat intel report, recent CVE, or MITRE technique
- Specific enough to be testable with available data
- Falsifiable (absence of evidence is also a result -- document it)

---

## Windows Event IDs

### Security log (Security.evtx)

| Event ID | Description | Hunt use |
|---------|-------------|---------|
| 4624 | Logon success | Look for unusual logon types (3=network, 10=remote interactive) |
| 4625 | Logon failure | Password spray: many 4625 from same source, different accounts |
| 4634 / 4647 | Logoff | Session duration analysis |
| 4648 | Explicit credential logon | Lateral movement; credential use from unusual process |
| 4656 | Handle to object requested | File access; filter by sensitive paths |
| 4663 | Object access attempt | Specific file/registry reads |
| 4688 | Process creation (with command line if auditing enabled) | Most useful process creation event |
| 4698 | Scheduled task created | Persistence |
| 4702 | Scheduled task updated | Persistence modification |
| 4720 | User account created | Backdoor account creation |
| 4722 | User account enabled | |
| 4728 | Member added to security-enabled global group | Privilege escalation |
| 4732 | Member added to security-enabled local group | Lateral / privilege |
| 4756 | Member added to universal group | |
| 4776 | Credential validation (NTLM) | Pass-the-hash; Kerberos golden ticket |
| 4768 | Kerberos TGT requested | Kerberoasting; odd service accounts |
| 4769 | Kerberos service ticket requested | Kerberoasting (look for RC4 encryption type 0x17) |
| 4771 | Kerberos pre-auth failed | Password spray against AD |
| 5140 | Network share access | SMB lateral movement |
| 5145 | Network share file access | |
| 7045 | New service installed | Persistence via service |
| 7034 | Service crashed unexpectedly | Exploit or shellcode crash |
| 7036 | Service state change | Service started/stopped |

### System log

| Event ID | Description |
|---------|-------------|
| 7045 | New service installed |
| 6005 / 6006 | System startup / shutdown |
| 104 | Audit log cleared -- high priority alert |

### PowerShell logs

| Event ID | Description | Notes |
|---------|-------------|-------|
| 4103 | Module logging | Full pipeline input/output |
| 4104 | Script block logging | Captures deobfuscated code |
| 4105 / 4106 | Script start/stop | |
| 400 / 600 (WinRM) | Remote session | Lateral movement via PowerShell remoting |

**Enable script block logging (GPO / registry):**
```
HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging
EnableScriptBlockLogging = 1
```

---

## Sysmon Event IDs

Sysmon must be installed and configured. A good config: [SwiftOnSecurity/sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config).

| Event ID | Description | Hunt use |
|---------|-------------|---------|
| 1 | Process creation (full command line + hashes + parent) | Core process chain analysis |
| 2 | File creation time changed | Timestomping detection |
| 3 | Network connection | C2 / exfil network activity |
| 5 | Process terminated | Ephemeral process detection |
| 6 | Driver loaded (with signing info) | Kernel-mode malware |
| 7 | DLL image loaded | DLL injection / hijacking |
| 8 | CreateRemoteThread | Process injection |
| 10 | ProcessAccess (e.g. lsass) | Credential dumping (e.g. Mimikatz) |
| 11 | File create | Drops in temp/appdata paths |
| 12 | Registry key created / deleted | Persistence |
| 13 | Registry value set | Persistence; RunKey writes |
| 14 | Registry key/value renamed | Evasion |
| 15 | File stream created (ADS) | Alternate Data Stream hide |
| 17 | Pipe created | Lateral movement (e.g. PsExec) |
| 18 | Pipe connected | |
| 22 | DNS query | C2 domain resolution |
| 23 | File delete | Anti-forensics / cleanup |
| 25 | Process tampering (process hollowing / herpaderping) | |
| 26 | File delete logged (event 23 with file archived) | |

---

## High-value hunt queries

### Suspicious parent-child process relationships (Sysmon Event 1)

```
ParentImage: "explorer.exe" AND Image: "cmd.exe" | rare
ParentImage: "winword.exe" AND Image: "powershell.exe"  # macro -> PS
ParentImage: "mshta.exe" OR ParentImage: "wscript.exe" OR ParentImage: "cscript.exe"
ParentImage: "svchost.exe" AND NOT CommandLine: "-k *"  # svchost spawning unusual children
Image: "powershell.exe" AND CommandLine: "*-enc*"       # base64 encoded PS
Image: "powershell.exe" AND CommandLine: "*bypass*"     # execution policy bypass
Image: "cmd.exe" AND CommandLine: "*ping* -n 1*"        # connectivity check (beacon staging)
```

### Credential access (Security Event 4688 / Sysmon 1)

```
Image: "*lsass*" AND EventID: 10          # LSASS access (Sysmon)
CommandLine: "*procdump* -ma lsass*"      # Procdump on LSASS
CommandLine: "*sekurlsa*" OR "*mimikatz*"
CommandLine: "*net user* /add*"           # New local user creation
```

### Persistence (Registry / Scheduled Tasks)

```
# Registry run keys (Sysmon 13)
TargetObject: "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\*"
TargetObject: "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\*"

# Scheduled tasks (Event 4698)
EventID: 4698 AND TaskContent: "*\AppData\*"   # task pointing to user-writable path
EventID: 4698 AND TaskContent: "*powershell*"

# Services (Event 7045)
ServiceType: "user mode service" AND ServiceFileName: "*\Temp\*"
```

### Network / C2

```
# Long connections to rare IPs (Sysmon 3)
NOT DestinationIp: "10.*" AND NOT DestinationIp: "192.168.*" AND NOT DestinationIp: "172.*"
Image: "powershell.exe" AND EventID: 3    # PS making network connections
DestinationPort: (4444 OR 8080 OR 1337 OR 31337 OR 9001)  # common C2 ports

# DNS to rare/DGA domains (Sysmon 22)
QueryResults: "" AND QueryName: *          # failed DNS (internal C2 trying to resolve)
QueryName: "*.onion.to" OR QueryName: "*.ngrok.io"
```

### Lateral movement

```
# PSExec indicators (Sysmon Pipe 17/18)
EventID: 17 AND PipeName: "\\PSEXESVC"

# WMI remote execution (Sysmon 1)
ParentImage: "WmiPrvSE.exe"

# Remote PowerShell (WinRM)
EventID: 4624 AND LogonType: 3 AND ProcessName: "*wsmprovhost*"

# Pass-the-Hash (Security)
EventID: 4624 AND LogonType: 3 AND AuthenticationPackageName: "NTLM"
```

---

## Splunk SPL cheat sheet

```spl
# Basic search
index=wineventlog EventCode=4688

# Process creation -- base64 PowerShell
index=sysmon EventCode=1 CommandLine="*-enc*" OR CommandLine="*-EncodedCommand*"
| table _time, host, ParentImage, Image, CommandLine

# Most common parent-child pairs (frequency analysis)
index=sysmon EventCode=1
| stats count by ParentImage, Image
| sort -count

# Logon failures grouped by source (spray detection)
index=wineventlog EventCode=4625
| stats count by src_ip, TargetUserName
| where count > 5
| sort -count

# New services
index=wineventlog EventCode=7045
| table _time, host, ServiceName, ServiceFileName

# Rare network connections by process
index=sysmon EventCode=3 NOT DestinationIp="10.*" NOT DestinationIp="192.168.*"
| stats count by Image, DestinationIp, DestinationPort
| where count < 3
| sort count
```

---

## Elastic DSL / KQL cheat sheet

```
# Process creation with encoded PS (KQL)
event.code: "1" and process.command_line: *-enc* 

# LSASS access attempts
event.code: "10" and winlog.event_data.TargetImage: *lsass*

# Rare parent-child
event.code: "1" and process.parent.name: "winword.exe" and process.name: ("powershell.exe" or "cmd.exe" or "wscript.exe")

# New scheduled task
event.code: "4698"

# Network by process
event.code: "3" and process.name: "powershell.exe" and not destination.ip: (10.0.0.0/8 or 192.168.0.0/16)
```

---

## Sigma rule skeleton

```yaml
title: Suspicious PowerShell Encoded Command
id: <generate with uuidgen>
status: experimental
description: Detects PowerShell launched with encoded command argument
author: Surrplexie
date: 2026/05/11
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        Image|endswith: '\powershell.exe'
        CommandLine|contains:
            - '-EncodedCommand'
            - '-enc '
            - '-ec '
    condition: selection
falsepositives:
    - Legitimate automation scripts using encoded commands
level: medium
tags:
    - attack.execution
    - attack.t1059.001
```

---

## IOC triage checklist (hunt)

When you identify a candidate IOC during analysis:

- [ ] Is it confirmed malicious or possibly benign (baseline)?
- [ ] Does it appear on VirusTotal / MalwareBazaar / threat intel feeds?
- [ ] How many hosts exhibit this IOC?
- [ ] Is there a corroborating second signal (network + process, or registry + file)?
- [ ] Can it be turned into a detection rule (SIEM query / Sigma)?
- [ ] Is it safe to document publicly (no internal hostname/account, no PII)?

---

## Confidence rating guide

| Level | Evidence |
|-------|---------|
| High | Multiple independent data sources agree; observable behavior; no plausible benign explanation |
| Medium | Single data source; consistent with hypothesis but alternative explanation possible |
| Low | Circumstantial; pattern matches but no direct confirmation; high false positive potential |
| Inconclusive | Data is insufficient or ambiguous; requires more data |

---

*See also: [`MITRE-coverage.md`](./MITRE-coverage.md) | [`tooling-reference.md`](./tooling-reference.md)*
