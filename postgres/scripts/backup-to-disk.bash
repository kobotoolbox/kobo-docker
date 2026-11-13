#!/usr/bin/env bash
set -e

# The cron task sets PGUSER; default to the cluster superuser when run by hand.
export PGUSER="${PGUSER:-$POSTGRES_USER}"

DBDATESTAMP="$(date +%Y.%m.%d.%H_%M)"
KPI_BACKUP_FILENAME="postgres-${KPI_POSTGRES_DB}-${PG_MAJOR}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.pg_dump"
KC_BACKUP_FILENAME="postgres-${KC_POSTGRES_DB}-${PG_MAJOR}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.pg_dump"
cd /srv/backups

# Dump to a temporary file and rename it only on success, so a failed dump
# never leaves an empty or truncated file that looks like a valid backup.
dump() {
    local db="$1" filename="$2"
    # Explicit `&&`: `set -e` is ignored inside a function called with `||`.
    pg_dump --format=custom --file="${filename}.tmp" "${db}" \
        && mv "${filename}.tmp" "${filename}" \
        && echo "Backup file \`${filename}\` created successfully."
}

rm -f ./*.pg_dump.tmp

# Backup `KPI` database only if it's different from KoBoCAT.
# Run it in background to dump both databases at the same time.
KPI_PID=""
if [ "$KPI_POSTGRES_DB" != "$KC_POSTGRES_DB" ]; then
    dump "${KPI_POSTGRES_DB}" "${KPI_BACKUP_FILENAME}" &
    KPI_PID=$!
fi

KC_STATUS=0
dump "${KC_POSTGRES_DB}" "${KC_BACKUP_FILENAME}" || KC_STATUS=$?

KPI_STATUS=0
if [ -n "$KPI_PID" ]; then
    wait "$KPI_PID" || KPI_STATUS=$?
fi

if [ "$KC_STATUS" -ne 0 ] || [ "$KPI_STATUS" -ne 0 ]; then
    echo "Backup FAILED (kobocat: ${KC_STATUS}, kpi: ${KPI_STATUS}). Previous backups were kept." >&2
    rm -f ./*.pg_dump.tmp
    exit 1
fi

# Keep only the backups that were just created.
find . -maxdepth 1 -name '*.pg_dump' \
    ! -name "${KC_BACKUP_FILENAME}" ! -name "${KPI_BACKUP_FILENAME}" -delete
