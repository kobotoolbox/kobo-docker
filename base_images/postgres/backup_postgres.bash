#!/usr/bin/env bash
set -e

timestamp="$(date +%Y.%m.%d.%H_%M)"
pg_dump -Z1 -Fc ${KOBO_POSTGRES_DB_NAME} > "/srv/backups/postgres_backup_${KOBO_POSTGRES_DB_NAME}__${timestamp}.pg_restore"
