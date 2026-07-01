#!/usr/bin/env bash
set -e

DBDATESTAMP="$(date +%Y.%m.%d.%H_%M)"
BACKUP_FILENAME="$1"
if [ -z "$BACKUP_FILENAME" ]; then
    BACKUP_FILENAME="redis-${REDIS_VERSION}-${PUBLIC_DOMAIN_NAME}-${DBDATESTAMP}.gz"
fi

cd /srv/backups
rm -rf *.gz
cp /data/enketo-main.rdb .
gzip -c enketo-main.rdb > ${BACKUP_FILENAME}
rm -rf *.rdb

echo "Backup file \`${BACKUP_FILENAME}\` created successfully."
