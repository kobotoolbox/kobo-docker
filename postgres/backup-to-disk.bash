#!/usr/bin/env bash
#set -e

DBDATESTAMP="$(date +%Y.%m.%d.%H_%M)"
BACKUP_FILENAME="postgres-${PG_MAJOR}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.pg_dump"
su - postgres -c "pg_dump --format=custom ${POSTGRES_DB}" > "/srv/backups/${BACKUP_FILENAME}"

echo "Backup file \`${BACKUP_FILENAME}\` created successfully."
