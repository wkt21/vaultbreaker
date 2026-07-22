#!/usr/bin/env bash
# Convenience launcher for the VaultBreaker challenge box.
set -e
cd "$(dirname "$0")"
docker compose up -d --build
echo
echo "VaultBreaker is running at http://localhost:8080"
echo "Target this host as you would any HTB-style box."
