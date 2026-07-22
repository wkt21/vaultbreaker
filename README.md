# VaultBreaker — HTB-style Challenge Box

An intentionally vulnerable **Hack-The-Box-style** challenge with a three-flag
escalation chain. Ships in two interchangeable formats:

- **Docker** — `docker compose up` (fastest, for quick tries)
- **VirtualBox/VMware OVA** — a full bootable VM, built from source

> Difficulty: Easy · Category: Web + Linux
> Tags: `lfi`, `file-upload`, `password-cracking`, `sudo`, `reverse-shell`

---

## Objectives

| # | Objective | How it is earned |
|---|-----------|-----------------|
| 1 | **Access the VM, find the flag** | Exploit a Local File Inclusion (LFI) bug in the document viewer to read `flag1.txt`. |
| 2 | **Find the admin credentials** | Leak the app config + SQLite DB via LFI, crack the admin password hash, authenticate to the admin console. |
| 3 | **Create a reverse shell** | Abuse the admin upload to deploy a PHP reverse shell, then escalate to `root` for the final flag. |

Flag format: `HTB{...}`. Full worked solution in [`docs/SOLUTION.md`](docs/SOLUTION.md).

---

## Quick start — Docker

```bash
git clone https://github.com/<you>/vaultbreaker.git
cd vaultbreaker
./start.sh            # or: docker compose up -d --build
```

Target: **http://localhost:8080**

## Quick start — OVA (VirtualBox)

Build the image from source (Linux host required):

```bash
sudo apt-get install -y qemu-utils debootstrap grub-pc-bin grub2-common mtools parted e2fsprogs
cd ova-build
sudo ./build-ova.sh        # -> ova-build/vaultbreaker.ova
```

Then in VirtualBox: **File → Import Appliance → vaultbreaker.ova**.
Console login: `root` / `vaultbreaker`. Attack surface: **TCP/80** (web) +
**TCP/22** (SSH). Import with EFI **off** (legacy BIOS/MBR image). Full details
in [`docs/OVA-USAGE.md`](docs/OVA-USAGE.md).

---

## Repository layout

```
vaultbreaker/
├── html/                       # vulnerable PHP web app (shared by Docker + OVA)
│   ├── view.php                #   [vuln] LFI via ?file=
│   ├── login.php               #   admin login (SHA-256 auth)
│   ├── admin.php               #   admin console (shows Flag 2)
│   ├── upload.php              #   [vuln] MIME-only upload check
│   ├── config.php              #   app config / DB path
│   └── pages/                  #   public docs + hints
├── flags/                      # flag1.txt (www-data) + flag3.txt (root-only)
├── payloads/                   # pentestmonkey php-reverse-shell.php
├── ova-build/                  # OVA build from source
│   ├── build-ova.sh            #   one-shot: debootstrap -> grub -> vmdk -> .ova
│   └── vaultbreaker.ovf        #   committed OVF descriptor (size patched at build)
├── docs/
│   ├── SOLUTION.md             # full writeup + commands
│   └── OVA-USAGE.md            # OVA import / networking / caveats
├── Dockerfile                  # Docker variant
├── docker-compose.yml          # exposes :8080
├── docker-entrypoint.sh        # seeds SQLite DB + perms on container start
├── start.sh                    # convenience launcher
├── LICENSE
└── README.md
```

---

## Flag & secret summary (for instructors)

| Item | Value | Location |
|------|-------|----------|
| Flag 1 | `HTB{lf1_g4v3_y0u_th3_f00th0ld}` | `/var/www/flag1.txt` (www-data readable) |
| Flag 2 | `HTB{cr4ck3d_th3_4dm1n_p4ssw0rd}` | Apache runtime env `VAULT_FLAG2` (SetEnv) |
| Flag 3 | `HTB{r00t_v1a_sud0_f1nd_r3vsh3ll}` | `/root/flag3.txt` (mode 0600, root-only) |
| Admin password | `letmein123` (SHA-256, in rockyou) | SQLite `users.db` |
| Console / SSH | `root` / `vaultbreaker` | VM login |

Flag 2 is deliberately **not** stored in any source file — it is injected into
the Apache runtime environment so the intended path (crack creds → log in) is
the clean route; an advanced LFI can still recover it from `/proc/self/environ`.

---

## Vulnerability summary

| Step | Bug | CWE |
|------|-----|-----|
| Flag 1 | LFI via unsanitized `include($_GET['file'])` | CWE-98 |
| Flag 2 | DB path leaked by LFI; weak, crackable admin password | CWE-547 / CWE-798 |
| Flag 3 | Upload validates MIME type only; PHP executes in `/uploads/` | CWE-434 |
| Flag 3 | Over-broad `sudo` grant on `find` | CWE-250 / CWE-269 |

---

## ⚠️ Safety

This is an intentionally vulnerable training image. Run it isolated; do not
expose its ports to untrusted networks. The OVA's SSH allows root password login
(`root`/`vaultbreaker`) for lab convenience — harden it before any wider use.

Educational use only.
