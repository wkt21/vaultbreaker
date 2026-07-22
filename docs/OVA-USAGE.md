# VaultBreaker — VirtualBox OVA

A bootable VirtualBox/VMware OVA image of the VaultBreaker HTB-style challenge
box (Debian 12 "Bookworm", 64-bit). Same 3-flag chain as the Docker variant,
packaged as an importable virtual machine.

- **VM:** 1 vCPU, 1024 MB RAM, 3 GB disk, IDE + E1000 NIC, SSH (port 22) enabled
- **Console login (instructor/debug):** `root` / `vaultbreaker`
- **Network:** DHCP on the first NIC (NAT by default). Attach to a Host-Only or
  Internal network if you want a private lab segment.
- **Attack surface:** TCP/80 (HTTP web app) + TCP/22 (SSH, root/vaultbreaker).
  The player discovers the VM's IP and treats it as any HTB target.

## Import

1. VirtualBox → **File → Import Appliance** → select `vaultbreaker.ova`.
2. Accept the hardware defaults (or bump RAM if you like). Click **Import**.
3. (Optional) Switch the network adapter from NAT to **Host-Only Adapter** /
   **Bridged** so the player machine can reach it.
4. Start the VM. It boots to a login prompt — no interaction needed; Apache
   starts automatically and the `vault-init` service seeds the database,
   permissions, and sudoers entry on first boot.

## Find the box IP (and make it reachable)

With NAT (the import default) the guest's port 80 is **not** directly reachable
from the host for HTB-style scanning. Either:
- switch Adapter 1 to **Host-Only Adapter** or **Bridged Adapter**, or
- keep NAT and add port forwarding (Settings → Network → Advanced → Port
  Forwarding): host `8080` → guest `80`, then target `http://localhost:8080`.

From the player host, scan for it:

```bash
# Host-Only / Bridged network — scan the relevant subnet:
nmap -sn 192.168.56.0/24
```

Or log into the VM console as `root` / `vaultbreaker` and run `ip a`.

The box exposes **two** services: **TCP/80** (HTTP web app — the attack surface)
and **TCP/22** (SSH). SSH is enabled for lab management with `PermitRootLogin yes`
and password auth, so you can also reach it directly:

```bash
ssh root@<vm-ip>     # password: vaultbreaker
```

(That SSH root-login policy is intentionally permissive for a private lab. Harden
it — `PermitRootLogin prohibit-password` + key-only auth — before exposing the
VM beyond your own machine.)

## The flags (same as the Docker box)

| # | Objective | Flag |
|---|-----------|------|
| 1 | LFI in `view.php` to read `/var/www/flag1.txt` | `HTB{lf1_g4v3_y0u_th3_f00th0ld}` |
| 2 | Leak config + SQLite via LFI, crack admin hash (`letmein123`), log in | `HTB{cr4ck3d_th3_4dm1n_p4ssw0rd}` |
| 3 | Upload PHP reverse shell via MIME-only upload bypass; privesc with `sudo find` | `HTB{r00t_v1a_sud0_f1nd_r3vsh3ll}` |

Full step-by-step commands: see `SOLUTION.md`.

## Build provenance & verification

This image was built from scratch with `debootstrap` (Debian bookworm),
`grub-install` (i386-pc target), and `qemu-img` (streamOptimized VMDK).
Verified in the build environment:

- Kernel + initrd present; GRUB MBR boot code installed; `grub.cfg` boots with
  `root=UUID=...` matching the partition UUID.
- `fstab` UUID matches the partition UUID.
- `apache2`, `systemd-networkd`, and `vault-init` services enabled.
- All three flags and the `SetEnv VAULT_FLAG2` Apache directive are in place.
- OVF is well-formed XML; OVA manifest SHA-256 hashes validate; OVF `ovf:size`
  matches the actual VMDK size.

The one thing that could **not** be verified in the build sandbox is an actual
cold boot (no KVM/VirtualBox there). If the first import fails to boot, the
most likely cause is a BIOS vs. UEFI mismatch — the image uses a legacy
BIOS/MBR (i386-pc) bootloader, so set the VM's **System → Motherboard →
Enable EFI** to **OFF** in VirtualBox settings.

## Reproduce the OVA from source

The OVA build scripts (`build-ova.sh`, `resume-ova.sh`, `fix-grub-repackage.sh`,
`finalize-ova.sh`) live alongside the `vaultbreaker/` source folder in the
build workspace, and the web app source is in `vaultbreaker/html/`. Rebuild on
a Linux host with: `qemu-utils`, `debootstrap`, `grub-pc-bin`,
`grub2-common`, `mtools`, `parted`, `e2fsprogs`.

> Educational use only. The box is intentionally vulnerable; do not expose it
> to untrusted networks.
