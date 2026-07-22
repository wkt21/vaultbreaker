#!/usr/bin/env bash
#
# build-ova.sh - Build the VaultBreaker VirtualBox/VMware OVA from source.
#
# Produces: ova-build/vaultbreaker.ova
#
# Run from anywhere, e.g.:
#     cd ova-build && sudo ./build-ova.sh
#
# Host requirements (Debian/Ubuntu):
#     apt-get install -y qemu-utils debootstrap grub-pc-bin grub2-common \
#                        mtools parted e2fsprogs
#
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"          # repository root
WORK="${WORK:-$HERE/build}"             # scratch dir (gitignored)
OUT="$HERE/vaultbreaker.ova"           # final artifact (gitignored)
IMG="$WORK/vaultbreaker.raw"
MNT="$WORK/mnt"

# ---- challenge constants ----
FLAG1=HTB{lf1_g4v3_y0u_th3_f00th0ld}
FLAG2=HTB{cr4ck3d_th3_4dm1n_p4ssw0rd}
FLAG3=HTB{r00t_v1a_sud0_f1nd_r3vsh3ll}
ROOT_PW=vaultbreaker
ADMIN_PW=letmein123
DISK_GB=3

log() { printf '\n\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '\033[1;31m[ERR]\033[0m %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "run with sudo (needs loop mounts + chroot)."

trap 'log "cleanup"; sync; umount -R "$MNT" 2>/dev/null || true; [ -n "${LOOP:-}" ] && losetup -d "$LOOP" 2>/dev/null || true' EXIT

mkdir -p "$WORK" "$MNT"

# ---------- 1. disk image + partition ----------
log "creating ${DISK_GB}G raw image"
qemu-img create -f raw "$IMG" "${DISK_GB}G" >/dev/null
LOOP="$(losetup -fP --show "$IMG")"
log "loop device: $LOOP"
parted -s "$LOOP" mklabel msdos
parted -s "$LOOP" mkpart primary ext4 1MiB 100%
parted -s "$LOOP" set 1 boot on
mkfs.ext4 -F -L rootfs "${LOOP}p1" >/dev/null
mount "${LOOP}p1" "$MNT"
UUID="$(blkid -s UUID -o value "${LOOP}p1")"
log "root uuid: $UUID"

# ---------- 2. base system ----------
log "debootstrap bookworm (this takes a few minutes)"
debootstrap --arch=amd64 --include=systemd,systemd-sysv bookworm "$MNT" http://deb.debian.org/debian

mount --bind /dev "$MNT/dev"
mount --bind /dev/pts "$MNT/dev/pts" 2>/dev/null || true
mount -t proc proc "$MNT/proc"
mount -t sysfs sysfs "$MNT/sys"
cp /etc/resolv.conf "$MNT/etc/resolv.conf"

# ---------- 3. install kernel / bootloader / web stack / ssh ----------
log "installing kernel, grub, apache, php, sqlite, sudo, ssh"
cat > "$MNT/stage2.sh" <<STAGE
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
  linux-image-amd64 \
  grub-pc-bin grub2-common \
  apache2 php libapache2-mod-php php-sqlite3 php-mbstring \
  sqlite3 sudo \
  systemd systemd-sysv \
  openssh-server
STAGE
chmod +x "$MNT/stage2.sh"
chroot "$MNT" /stage2.sh

# ---------- 4. system config ----------
log "system config (fstab, network, root pw)"
echo "root:${ROOT_PW}" | chroot "$MNT" chpasswd
echo "vaultbreaker" > "$MNT/etc/hostname"
cat > "$MNT/etc/fstab" <<FSTAB
UUID=$UUID / ext4 errors=remount-ro 0 1
proc /proc proc defaults 0 0
FSTAB

# DHCP on any ethernet name (enp0s3, eth0, etc.)
mkdir -p "$MNT/etc/systemd/network"
cat > "$MNT/etc/systemd/network/20-wired.network" <<NET
[Match]
Name=en* eth*

[Network]
DHCP=yes
NET
chroot "$MNT" systemctl enable systemd-networkd.service
chroot "$MNT" systemctl enable systemd-resolved.service 2>/dev/null || true
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > "$MNT/etc/resolv.conf"

# ---------- 5. deploy challenge ----------
log "deploying web app + flags"
rm -f "$MNT/var/www/html/index.html"
cp -r "$SRC/html/." "$MNT/var/www/html/"
printf '%s\n' "$FLAG1" > "$MNT/var/www/flag1.txt"
printf '%s\n' "$FLAG3" > "$MNT/root/flag3.txt"

# Flag 2 only in the Apache runtime env (not in any source file).
cat > "$MNT/etc/apache2/conf-available/vault.conf" <<APACHE
SetEnv VAULT_FLAG2 $FLAG2
APACHE
chroot "$MNT" a2enconf vault >/dev/null
chroot "$MNT" a2enmod php8.2 2>/dev/null || chroot "$MNT" a2enmod php 2>/dev/null || true
cat > "$MNT/etc/apache2/mods-enabled/dir.conf" <<'DIR'
<IfModule mod_dir.c>
    DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm
</IfModule>
DIR
chroot "$MNT" systemctl enable apache2.service

# boot-time init: seed DB, perms, sudoers
cat > "$MNT/usr/local/bin/vault-init.sh" <<INIT
#!/bin/bash
set -e
ADMIN_HASH=\$(echo -n "$ADMIN_PW" | sha256sum | awk '{print \$1}')
mkdir -p /var/www/html/data /var/www/html/uploads /var/www/html/pages
sqlite3 /var/www/html/data/users.db \\
  "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL);
   DELETE FROM users;
   INSERT INTO users (username, password_hash) VALUES ('admin','\${ADMIN_HASH}');"
chown -R www-data:www-data /var/www/html/data /var/www/html/uploads
chown www-data:www-data /var/www/flag1.txt
chmod 644 /var/www/flag1.txt
chown root:root /root/flag3.txt
chmod 600 /root/flag3.txt
echo 'www-data ALL=(ALL) NOPASSWD: /usr/bin/find' > /etc/sudoers.d/vault
chmod 440 /etc/sudoers.d/vault
INIT
chmod +x "$MNT/usr/local/bin/vault-init.sh"
cat > "$MNT/etc/systemd/system/vault-init.service" <<'UNIT'
[Unit]
Description=VaultBreaker challenge init
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/vault-init.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
chroot "$MNT" systemctl enable vault-init.service

# ---------- 6. SSH ----------
log "configuring ssh (port 22, root password login for lab access)"
SSHD="$MNT/etc/ssh/sshd_config"
set_conf() { grep -q "^$1" "$SSHD" && sed -i "s|^$1.*|$1 $2|" "$SSHD" || echo "$1 $2" >> "$SSHD"; }
set_conf PermitRootLogin yes
set_conf PasswordAuthentication yes
set_conf Banner /etc/issue.net
printf 'VaultBreaker - authorized access only\n' > "$MNT/etc/issue.net"
chroot "$MNT" ssh-keygen -A >/dev/null 2>&1 || true
chroot "$MNT" systemctl enable ssh.socket 2>/dev/null || true
chroot "$MNT" systemctl enable ssh.service 2>/dev/null || true

# ---------- 7. GRUB ----------
log "installing grub (i386-pc / legacy BIOS-MBR)"
cat > "$MNT/etc/default/grub" <<GRUB
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR=VaultBreaker
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_TERMINAL=console
GRUB_DISABLE_LINUX_UUID=false
GRUB_DISABLE_RECOVERY=true
GRUB
grub-install --target=i386-pc --boot-directory="$MNT/boot" --modules="part_msdos ext2 normal" "$LOOP"
chroot "$MNT" grub-mkconfig -o /boot/grub/grub.cfg

# FIX: grub-mkconfig writes root=/dev/<loop>p1 (the chroot device name).
# Rewrite it to the stable partition UUID so the VM boots under /dev/sda1.
LOOPNAME="$(basename "$LOOP")"
sed -i "s|root=/dev/${LOOPNAME}p1|root=UUID=${UUID}|g" "$MNT/boot/grub/grub.cfg"
log "grub root line: $(grep -m1 -oE 'root=UUID=[a-f0-9-]+' "$MNT/boot/grub/grub.cfg")"

# ---------- 8. unmount + convert ----------
log "unmounting + converting to streamOptimized VMDK"
sync
umount -R "$MNT/dev" 2>/dev/null || true
umount "$MNT/proc" 2>/dev/null || true
umount "$MNT/sys" 2>/dev/null || true
umount "$MNT" 2>/dev/null || true
losetup -d "$LOOP"; LOOP=""
qemu-img convert -f raw -O vmdk -o subformat=streamOptimized "$IMG" "$WORK/vaultbreaker-disk001.vmdk"

# ---------- 9. package OVA ----------
log "packaging OVA"
VMDK="$WORK/vaultbreaker-disk001.vmdk"
VMDK_SIZE="$(stat -c %s "$VMDK")"
cp "$HERE/vaultbreaker.ovf" "$WORK/vaultbreaker.ovf"
sed -i "s|ovf:size=\"[0-9]*\"|ovf:size=\"${VMDK_SIZE}\"|" "$WORK/vaultbreaker.ovf"
OVF_SHA="$(sha256sum "$WORK/vaultbreaker.ovf" | awk '{print $1}')"
VMDK_SHA="$(sha256sum "$VMDK" | awk '{print $1}')"
cat > "$WORK/vaultbreaker.mf" <<MF
SHA256(vaultbreaker.ovf)= ${OVF_SHA}
SHA256(vaultbreaker-disk001.vmdk)= ${VMDK_SHA}
MF
( cd "$WORK" && tar -cf "$OUT" vaultbreaker.ovf vaultbreaker-disk001.vmdk vaultbreaker.mf )

# hand ownership back to the invoking user
if [ -n "${SUDO_USER:-}" ]; then chown "$SUDO_USER:$SUDO_USER" "$OUT" 2>/dev/null || true; fi

log "DONE -> $OUT ($(du -h "$OUT" | cut -f1))"
log "console login: root / ${ROOT_PW}   |   attack surface: tcp/80 (web) + tcp/22 (ssh)"
