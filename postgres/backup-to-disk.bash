#!/usr/bin/env bash
set -e

DBDATESTAMP="$(date +%Y.%m.%d.%H_%M)"
KPI_BACKUP_FILENAME="postgres-${KPI_POSTGRES_DB}-${PG_MAJOR}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.pg_dump"
KC_BACKUP_FILENAME="postgres-${KC_POSTGRES_DB}-${PG_MAJOR}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.pg_dump"
cd /srv/backups
rm -rf *.pg_dump

# Backup `KPI` database only if it's different from KoBoCAT
# Make it run in background to be run at same time as KoBoCAT's backup.
if [ "$KPI_POSTGRES_DB" != "$KC_POSTGRES_DB" ]; then
    pg_dump --format=custom ${KPI_POSTGRES_DB} > "${KPI_BACKUP_FILENAME}" && echo "Backup files \`${KPI_BACKUP_FILENAME}\` created successfully." &
fi

pg_dump --format=custom ${KC_POSTGRES_DB} > "${KC_BACKUP_FILENAME}"
echo "Backup files \`${KC_BACKUP_FILENAME}\` created successfully."
