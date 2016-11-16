#!/usr/bin/env bash
set -e

timestamp="$(date +%Y.%m.%d.%H_%M)"
backup_filename="mongo_backup__${timestamp}.mongorestore.tar.gz"

cd /srv/backups
rm -rf dump
mongodump
tar -czf "${backup_filename}" dump
rm -rf dump

echo "Backup file \`${backup_filename}\` created successfully."
