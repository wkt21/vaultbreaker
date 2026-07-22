#!/bin/bash
set -e

mkdir -p /var/www/html/data /var/www/html/uploads /var/www/html/pages
chown -R www-data:www-data /var/www/html/data /var/www/html/uploads /var/www/html/pages

# Seed the application database. The admin password is "letmein123" (present in
# rockyou.txt) stored as a SHA-256 hash -- the credential the player must crack
# to satisfy the Flag 2 objective.
ADMIN_HASH=$(echo -n "letmein123" | sha256sum | awk '{print $1}')

sqlite3 /var/www/html/data/users.db <<SQL
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL
);
DELETE FROM users;
INSERT INTO users (username, password_hash) VALUES ('admin', '${ADMIN_HASH}');
SQL

chown www-data:www-data /var/www/html/data/users.db
chmod 640 /var/www/html/data/users.db

exec apache2-foreground
