<?php
// FileVault internal configuration.
// This file is NOT served directly by Apache, but it IS readable by the web
// process -- a Local File Inclusion bug elsewhere will leak its contents.

define('DB_PATH', __DIR__ . '/data/users.db');
define('DB_USER', 'vault_app');
define('DB_PASS', 'S3cur3VaultDBP@ss!2024');
define('UPLOAD_DIR', __DIR__ . '/uploads/');
define('APP_NAME', 'FileVault Secure Documents');
