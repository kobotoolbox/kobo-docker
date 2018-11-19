#!/usr/bin/env bash
set -e

DBDATESTAMP="$(date +%Y.%m.%d.%H_%M)"
BACKUP_FILENAME="mongo-${MONGO_MAJOR}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.gz"

cd /srv/backups
rm -rf *.gz
mongodump --archive="${BACKUP_FILENAME}" --gzip

echo "Backup file \`${BACKUP_FILENAME}\` created successfully."
