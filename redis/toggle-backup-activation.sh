#!/usr/bin/env bash


rm -f /etc/cron.d/backup_redis_crontab
if [[ -z "${REDIS_BACKUP_SCHEDULE}" ]]; then
    echo "Redis automatic backups disabled."
else
    # Install cron in case if not present
    echo "Installing cron..."
    apt-get update --quiet=2 > /dev/null
    apt-get install -y cron --quiet=2 > /dev/null

    # Pass env variables to cron task
    echo "REDIS_VERSION=${REDIS_VERSION}" >> /etc/cron.d/backup_redis_crontab
    echo "PUBLIC_DOMAIN_NAME=${PUBLIC_DOMAIN_NAME}" >> /etc/cron.d/backup_redis_crontab

    # To use S3 as storage, AWS access key, secret key and bucket name must filled up
    USE_S3=1
    TRUE=1
    FALSE=0

    # Add only non-empty variable to cron tasks
    if [ ! -z "${AWS_ACCESS_KEY_ID}" ]; then
        echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> /etc/cron.d/backup_redis_crontab
    else
        USE_S3=$FALSE
    fi

    if [ ! -z "${AWS_SECRET_ACCESS_KEY}" ]; then
        echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" >> /etc/cron.d/backup_redis_crontab
    else
        USE_S3=$FALSE
    fi

    if [ ! -z "${BACKUP_AWS_STORAGE_BUCKET_NAME}" ]; then
        echo "BACKUP_AWS_STORAGE_BUCKET_NAME=${BACKUP_AWS_STORAGE_BUCKET_NAME}" >> /etc/cron.d/backup_redis_crontab
    else
        USE_S3=$FALSE
    fi

    if [ ! -z "${AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED}" ]; then
        echo "AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED=${AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED}" >> /etc/cron.d/backup_redis_crontab
    fi
    if [ ! -z "${AWS_BACKUP_YEARLY_RETENTION}" ]; then
        echo "AWS_BACKUP_YEARLY_RETENTION=${AWS_BACKUP_YEARLY_RETENTION}" >> /etc/cron.d/backup_redis_crontab
    fi
    if [ ! -z "${AWS_BACKUP_MONTHLY_RETENTION}" ]; then
        echo "AWS_BACKUP_MONTHLY_RETENTION=${AWS_BACKUP_MONTHLY_RETENTION}" >> /etc/cron.d/backup_redis_crontab
    fi
    if [ ! -z "${AWS_BACKUP_WEEKLY_RETENTION}" ]; then
        echo "AWS_BACKUP_WEEKLY_RETENTION=${AWS_BACKUP_WEEKLY_RETENTION}" >> /etc/cron.d/backup_redis_crontab
    fi
    if [ ! -z "${AWS_BACKUP_DAILY_RETENTION}" ]; then
        echo "AWS_BACKUP_DAILY_RETENTION=${AWS_BACKUP_DAILY_RETENTION}" >> /etc/cron.d/backup_redis_crontab
    fi
    if [ ! -z "${AWS_REDIS_BACKUP_MINIMUM_SIZE}" ]; then
        echo "AWS_REDIS_BACKUP_MINIMUM_SIZE=${AWS_REDIS_BACKUP_MINIMUM_SIZE}" >> /etc/cron.d/backup_redis_crontab
    fi

    if [ "$USE_S3" -eq "$TRUE" ]; then
        echo "Installing virtualenv for Redis backup on S3..."
        apt-get install -y s3cmd --quiet=2 > /dev/null
        apt-get install -y python-virtualenv --quiet=2 > /dev/null
        virtualenv /tmp/backup-virtualenv
        . /tmp/backup-virtualenv/bin/activate
        pip install --quiet boto
        deactivate

        INTERPRETER=/tmp/backup-virtualenv/bin/python
        BACKUP_SCRIPT="/kobo-docker-scripts/backup-to-s3.py"
    else
        INTERPRETER=$(command -v bash)
        BACKUP_SCRIPT="/kobo-docker-scripts/backup-to-disk.bash"
    fi

    # Should we first validate the schedule e.g. with `chkcrontab`?
    echo "${REDIS_BACKUP_SCHEDULE}  root    ${INTERPRETER} ${BACKUP_SCRIPT} > /var/log/redis/backup.log 2>&1" >> /etc/cron.d/backup_redis_crontab
    echo "" >> /etc/cron.d/backup_redis_crontab
    service cron restart
    echo "Redis automatic backup schedule: ${REDIS_BACKUP_SCHEDULE}"
fi
