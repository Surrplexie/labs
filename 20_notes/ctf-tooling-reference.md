# CTF Tooling Reference

**Quick reference for tools used across CTF, HackTheBox, and TryHackMe engagements.**

Covers recon, web, pwn, rev, crypto, and miscellaneous tools. For malware analysis
tooling (DIE, PEStudio, Procmon, etc.) see [`tooling-reference.md`](./tooling-reference.md).

---

## Recon and Enumeration

### nmap

**Purpose:** Port scanning and service/version detection.

| Flag | What it does |
|------|-------------|
| `-sC` | Run default scripts |
| `-sV` | Version detection |
| `-p-` | All 65535 ports (slow but thorough) |
| `-T4` | Faster timing (use carefully on rate-limited targets) |
| `--open` | Show only open ports |
| `-oA <name>` | Save output in all formats (nmap, gnmap, xml) |
| `-A` | OS detection + version + scripts + traceroute |

**Common starting scan:**
```bash
nmap -sC -sV -oA nmap/initial <IP>
# Full port scan (run in background)
nmap -p- --min-rate 10000 -oA nmap/fullports <IP>
```

**Key signals:**
- Port 22 (SSH), 80/443 (HTTP/S), 21 (FTP), 23 (Telnet), 445 (SMB), 3389 (RDP)
- `Service Info: OS: Windows` / `Linux` in script output
- Outdated version strings (e.g. `OpenSSH 7.2p2 Ubuntu` -> Ubuntu 16.04 era)
- Anonymous FTP (`ftp-anon: Anonymous FTP login allowed`)

---

### gobuster / feroxbuster

**Purpose:** Web directory and file brute-force enumeration.

```bash
# Directory brute force
gobuster dir -u http://TARGET -w /usr/share/wordlists/dirb/common.txt -x php,html,txt

# DNS subdomain brute force
gobuster dns -d TARGET.com -w /usr/share/wordlists/subdomains.txt

# feroxbuster (recursive by default -- faster)
feroxbuster -u http://TARGET -w /usr/share/seclists/Discovery/Web-Content/common.txt

# Quiet, common extensions
feroxbuster -u http://TARGET -x php,aspx,html,txt -q
```

**Key signals:** 200/301/302 on non-standard paths, admin panels, backup files (`.bak`, `.old`), config files.

---

### ffuf

**Purpose:** Fast web fuzzer -- directories, subdomains, parameter fuzzing.

```bash
# Subdomain fuzzing
ffuf -u http://FUZZ.target.htb -H "Host: FUZZ.target.htb" -w subdomains.txt -fs <filter_size>

# Parameter fuzzing
ffuf -u http://target/page?FUZZ=value -w params.txt

# POST body fuzzing
ffuf -u http://target/login -X POST -d "user=FUZZ&pass=admin" -w users.txt -mc 302
```

---

### enum4linux-ng / smbclient

**Purpose:** SMB enumeration on Windows targets.

```bash
# Enumerate everything
enum4linux-ng -A <IP>

# List SMB shares (anonymous)
smbclient -L //<IP>/ -N

# Connect to a share
smbclient //<IP>/SHARE -N
```

---

### ldapdomaindump / ldapsearch

**Purpose:** Active Directory / LDAP enumeration.

```bash
ldapdomaindump -u 'DOMAIN\user' -p 'password' <DC_IP>
ldapsearch -x -H ldap://<IP> -b "dc=domain,dc=local"
```

---

## Web Exploitation

### Burp Suite

**Purpose:** HTTP proxy -- intercept, replay, fuzz web requests.

**Key signals to look for:**
- Hidden form fields (`type="hidden"`)
- Predictable tokens or session IDs (not random-looking)
- Different responses on different input (SQL error strings, timing differences)
- Stack traces leaking framework, path, or DB info
- Cookies without `HttpOnly` or `Secure` flags

**Common workflow:**
1. Proxy browser traffic through Burp (127.0.0.1:8080).
2. Capture login or key request.
3. Send to **Repeater** for manual testing.
4. Send to **Intruder** for fuzzing (use Cluster Bomb / Sniper).
5. Use **Decoder** for base64/URL/hex decoding.

---

### SQLmap

**Purpose:** Automated SQL injection detection and exploitation.

```bash
# Basic test on URL parameter
sqlmap -u "http://target/page?id=1" --dbs

# With cookie (authenticated)
sqlmap -u "http://target/page?id=1" --cookie="session=abc123" --dbs

# POST parameter
sqlmap -u "http://target/login" --data="user=test&pass=test" -p user --dbs

# Dump a table
sqlmap -u "http://target/page?id=1" -D database -T users --dump
```

**Gotcha:** SQLmap is noisy -- use `--level` and `--risk` carefully. Note the injection type in your notes (UNION, blind, time-based).

---

### CyberChef

**Purpose:** Browser-based encoding/decoding/crypto Swiss Army knife.

URL: [gchq.github.io/CyberChef](https://gchq.github.io/CyberChef/)

**Useful "recipes":**
- Magic (auto-detect encoding)
- From Base64 / To Base64
- From Hex / To Hex
- XOR (key brute-force)
- JWT Decode
- Gunzip / Inflate
- Parse DateTime

---

## Password Cracking

### hashcat

**Purpose:** GPU-accelerated hash cracking.

```bash
# Identify hash type first (e.g. hash-identifier or haiti)
hashcat --identify hash.txt

# Dictionary attack
hashcat -m 0 hash.txt /usr/share/wordlists/rockyou.txt        # MD5
hashcat -m 1000 hash.txt rockyou.txt                           # NTLM
hashcat -m 1800 hash.txt rockyou.txt                           # sha512crypt (Linux)

# Rule-based
hashcat -m 0 hash.txt rockyou.txt -r /usr/share/hashcat/rules/best64.rule

# Hybrid (wordlist + mask)
hashcat -m 0 -a 6 hash.txt rockyou.txt "?d?d?d"
```

**Common hash modes:** 0=MD5, 100=SHA1, 1000=NTLM, 1400=SHA256, 1800=sha512crypt, 3200=bcrypt

---

### John the Ripper

**Purpose:** CPU hash cracking + format conversion.

```bash
# Crack with rockyou
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt

# Auto-detect format
john hash.txt --format=auto

# Convert format first (e.g. zip to john format)
zip2john archive.zip > hash.txt
john hash.txt
```

---

## Reverse Engineering (CTF)

### Ghidra

**Purpose:** Free NSA decompiler -- converts binary to pseudo-C.

**Workflow:**
1. File > New Project, import binary.
2. Auto-analyse (accept defaults).
3. Functions list on left -- look for `main` or suspicious function names.
4. Double-click to decompile. Right-click -> Rename Function/Variable for clarity.
5. Search -> Search for Strings for hardcoded values.

**Key signals:** XOR loops (obfuscation), strcmp calls (password checks), hardcoded keys, anti-debug calls.

---

### GDB + pwndbg / peda

**Purpose:** Dynamic debugger for Linux binary exploitation.

```bash
# With pwndbg
gdb ./binary
run
info functions
disas main
break *0x401234
x/10gx $rsp           # examine stack
```

---

### pwntools

**Purpose:** Python library for writing exploit scripts.

```python
from pwn import *

p = process('./binary')       # local
p = remote('target', 1337)    # remote

payload = b'A' * 64 + p64(0xdeadbeef)
p.sendline(payload)
p.interactive()
```

---

### strings / file / readelf / objdump

```bash
file binary               # identify type
strings binary | grep -i flag   # quick string grep
strings binary | grep -E "http|ftp|ssh"
readelf -s binary         # symbol table
objdump -d binary | head -100   # disassembly preview
```

---

## Cryptography (CTF)

### Common patterns

| Observation | Likely technique | Tool |
|------------|-----------------|------|
| Looks like base64 | Base64 encoding | `base64 -d` / CyberChef |
| All hex | Hex encoding | CyberChef From Hex |
| Repeating pattern | XOR with short key | CyberChef XOR Brute Force |
| `$2b$`, `$2y$` prefix | bcrypt | hashcat -m 3200 |
| `$6$` prefix | sha512crypt | hashcat -m 1800 |
| RSA-shaped (n, e, c) | RSA (check small e, n factorability) | RsaCtfTool |
| Numbers only, unusual size | RSA or custom math cipher | sage / python |
| `-----BEGIN PGP` | PGP / GPG | `gpg --decrypt` |

### RsaCtfTool

```bash
python3 RsaCtfTool.py -n <n> -e <e> --decrypt <ciphertext_hex>
# Auto-attack weak RSA parameters
python3 RsaCtfTool.py --publickey key.pem --decrypt cipher.txt
```

---

## Forensics (CTF)

### exiftool

```bash
exiftool file.jpg          # all metadata
exiftool -Comment file.png # specific field
```

### steghide / stegsolve / zsteg

```bash
steghide extract -sf image.jpg           # extract hidden data (with passphrase)
steghide info image.jpg                  # check if anything embedded
zsteg image.png                          # auto-check LSB and other steg
```

### binwalk

```bash
binwalk -e archive.bin     # extract embedded files
binwalk --dd='.*' file     # extract all signatures
```

### Volatility (memory forensics)

```bash
vol -f memory.raw windows.pslist         # process list
vol -f memory.raw windows.cmdline        # command line args
vol -f memory.raw windows.netscan        # network connections
vol -f memory.raw windows.filescan       # file handles
```

---

## Common Gotchas

- **Encoding is not encryption.** Base64 in a CTF is usually just encoding, not security.
- **Check the source.** `Ctrl+U` in browser -- CTF flags are sometimes in HTML comments.
- **robots.txt and sitemap.xml** often reveal paths gobuster misses.
- **File extensions lie.** A `.png` may be a ZIP; run `file` on everything suspicious.
- **"Try harder"** is rarely the answer -- enumerate more thoroughly before trying complex exploits.
- **Note every dead end.** Rabbit holes documented in `02_dynamic` prevent repeating them.

---

*See also: [`tooling-reference.md`](./tooling-reference.md) for malware analysis tooling.*  
*See also: [`MITRE-coverage.md`](./MITRE-coverage.md) for ATT&CK technique tracking.*
