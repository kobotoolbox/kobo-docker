#!/usr/bin/env bash
set -e
source /etc/profile

rm -f /etc/cron.d/backup_mongo_crontab
if [[ -z "${MONGO_BACKUP_SCHEDULE}" ]]; then
    echo 'MongoDB automatic backups disabled.'
else
    # Should we first validate the schedule e.g. with `chkcrontab`?
    cat "/srv/backup_mongo_crontab.envsubst" | envsubst > /etc/cron.d/backup_mongo_crontab
    echo "MongoDB automatic backup schedule: ${MONGO_BACKUP_SCHEDULE}"
fi
