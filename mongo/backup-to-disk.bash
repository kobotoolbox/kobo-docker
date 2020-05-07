#!/usr/bin/env bash
set -e

DBDATESTAMP="$(date +%Y.%m.%d.%H_%M)"
BACKUP_FILENAME="mongo-${MONGO_MAJOR}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.gz"

cd /srv/backups
rm -rf *.gz

if [[ -n "${MONGO_INITDB_ROOT_USERNAME}" ]] && [[ -n "${MONGO_INITDB_ROOT_PASSWORD}" ]]; then
    mongodump --archive="${BACKUP_FILENAME}" --gzip --username="${MONGO_INITDB_ROOT_USERNAME}" --password="${MONGO_INITDB_ROOT_PASSWORD}"
else
    mongodump --archive="${BACKUP_FILENAME}" --gzip
fi

echo "Backup file \`${BACKUP_FILENAME}\` created successfully."
