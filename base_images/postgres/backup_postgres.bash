#!/usr/bin/env bash
set -e

timestamp="$(date +%Y.%m.%d.%H_%M)"
pg_dump --compress=1 --format=custom ${KOBO_POSTGRES_DB_NAME} > "/srv/backups/postgres_backup_${KOBO_POSTGRES_DB_NAME}__${timestamp}.pg_restore"
