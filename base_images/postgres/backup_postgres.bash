#!/usr/bin/env bash
set -e

timestamp="$(date +%Y.%m.%d.%H_%M)"
backup_filename="postgres_backup_${KOBO_POSTGRES_DB_NAME}__${timestamp}.pg_restore"
su - postgres -c "pg_dump --compress=1 --format=custom ${KOBO_POSTGRES_DB_NAME}" > "/srv/backups/${backup_filename}"
echo "Backup file \`${backup_filename}\` created successfully."
