#!/usr/bin/env bash

TIMESTAMP="$(date +%Y.%m.%d.%H_%M)"
BACKUP_FILENAME="postgres_backup_${POSTGRES_DB_NAME}_${TIMESTAMP}.pg_dump"
su - postgres -c "pg_dump --compress=2 --format=custom ${POSTGRES_DB_NAME}" > "/srv/backups/${BACKUP_FILENAME}"
echo "Backup file \`${BACKUP_FILENAME}\` created successfully."