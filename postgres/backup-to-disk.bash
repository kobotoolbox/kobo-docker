#!/usr/bin/env bash
set -e

DBDATESTAMP="$(date +%Y.%m.%d.%H_%M)"
BACKUP_FILENAME="postgres-${PG_MAJOR}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.pg_dump"
cd /srv/backups
rm -rf *.pg_dump
pg_dump --format=custom ${POSTGRES_DB} > "${BACKUP_FILENAME}"

echo "Backup file \`${BACKUP_FILENAME}\` created successfully."
