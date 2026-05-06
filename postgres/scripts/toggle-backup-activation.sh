#!/usr/bin/env bash

rm -f /etc/cron.d/backup_postgres_crontab
if [[ (-z "${POSTGRES_BACKUP_SCHEDULE}") || ("${POSTGRES_BACKUP_FROM_SECONDARY}" == "True") ]]; then
    echo "PostgreSQL automatic backups disabled."
else
    # Install cron in case if not present
    echo "Installing cron..."
    apt-get update --quiet=2 > /dev/null
    apt-get install -y cron --quiet=2 > /dev/null

    # Pass env variables to cron task
    echo "PG_MAJOR=${PG_MAJOR}" >> /etc/cron.d/backup_postgres_crontab
    echo "PUBLIC_DOMAIN_NAME=${PUBLIC_DOMAIN_NAME}" >> /etc/cron.d/backup_postgres_crontab
    echo "POSTGRES_HOST=${POSTGRES_HOST}" >> /etc/cron.d/backup_postgres_crontab
    echo "PGUSER=${POSTGRES_USER}" >> /etc/cron.d/backup_postgres_crontab
    echo "KPI_POSTGRES_DB=${KPI_POSTGRES_DB}" >> /etc/cron.d/backup_postgres_crontab
    echo "KC_POSTGRES_DB=${KC_POSTGRES_DB}" >> /etc/cron.d/backup_postgres_crontab
    echo "KPI_DATABASE_URL=${KPI_DATABASE_URL}" >> /etc/cron.d/backup_postgres_crontab
    echo "KC_DATABASE_URL=${KC_DATABASE_URL}" >> /etc/cron.d/backup_postgres_crontab

    # Add only non-empty variable to cron tasks
    if [[ -n "${AWS_ACCESS_KEY_ID}" ]]; then
        echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> /etc/cron.d/backup_postgres_crontab
    fi

    if [[ -n "${AWS_SECRET_ACCESS_KEY}" ]]; then
        echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" >> /etc/cron.d/backup_postgres_crontab
    fi

    if [[ -n "${BACKUP_AWS_STORAGE_BUCKET_NAME}" ]]; then
        echo "BACKUP_AWS_STORAGE_BUCKET_NAME=${BACKUP_AWS_STORAGE_BUCKET_NAME}" >> /etc/cron.d/backup_postgres_crontab
    fi

    if [[ -n "${AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED}" ]]; then
        echo "AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED=${AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED}" >> /etc/cron.d/backup_postgres_crontab
    fi
    if [[ -n "${AWS_BACKUP_YEARLY_RETENTION}" ]]; then
        echo "AWS_BACKUP_YEARLY_RETENTION=${AWS_BACKUP_YEARLY_RETENTION}" >> /etc/cron.d/backup_postgres_crontab
    fi
    if [[ -n "${AWS_BACKUP_MONTHLY_RETENTION}" ]]; then
        echo "AWS_BACKUP_MONTHLY_RETENTION=${AWS_BACKUP_MONTHLY_RETENTION}" >> /etc/cron.d/backup_postgres_crontab
    fi
    if [[ -n "${AWS_BACKUP_WEEKLY_RETENTION}" ]]; then
        echo "AWS_BACKUP_WEEKLY_RETENTION=${AWS_BACKUP_WEEKLY_RETENTION}" >> /etc/cron.d/backup_postgres_crontab
    fi
    if [[ -n "${AWS_BACKUP_DAILY_RETENTION}" ]]; then
        echo "AWS_BACKUP_DAILY_RETENTION=${AWS_BACKUP_DAILY_RETENTION}" >> /etc/cron.d/backup_postgres_crontab
    fi
    if [[ -n "${AWS_POSTGRES_BACKUP_MINIMUM_SIZE}" ]]; then
        echo "AWS_POSTGRES_BACKUP_MINIMUM_SIZE=${AWS_POSTGRES_BACKUP_MINIMUM_SIZE}" >> /etc/cron.d/backup_postgres_crontab
    fi

    if [[ -n "${BACKUP_AWS_STORAGE_BUCKET_NAME}" ]]; then
        apt-get install -y curl python3-pip python3-venv libffi-dev --quiet=2 > /dev/null

        echo "Installing virtualenv for PostgreSQL backup on S3..."
        counter=1
        max_retries=3
        # Under certain circumstances a race condition occurs. Virtualenv creation
        # fails because python cannot find `wheel` package folder
        # e.g. `FileNotFoundError: [Errno 2] No such file or directory: '/root/.local/share/virtualenv/wheel/3.5/embed/1/wheel.json'`
        until $(python3 -m venv /tmp/backup-virtualenv > /dev/null)
        do
            [[ "$counter" -eq "$max_retries" ]] && echo "Virtual environment creation failed!" && exit 1
            ((counter++))
        done
        . /tmp/backup-virtualenv/bin/activate
        pip install --quiet humanize smart-open[s3]
        pip install --quiet boto3
        deactivate

        CRON_CMD="${POSTGRES_BACKUP_SCHEDULE}  root    /usr/bin/nice -n 19 /usr/bin/ionice -c2 -n7 /tmp/backup-virtualenv/bin/python /kobo-docker-scripts/scripts/backup-to-s3.py > /srv/logs/backup.log 2>&1"
    else
        CRON_CMD="${POSTGRES_BACKUP_SCHEDULE}  root    /usr/bin/nice -n 19 /usr/bin/ionice -c2 -n7 /bin/bash /kobo-docker-scripts/scripts/backup-to-disk.bash > /srv/logs/backup.log 2>&1"
    fi

    # Should we first validate the schedule e.g. with `chkcrontab`?
    echo "${CRON_CMD}" >> /etc/cron.d/backup_postgres_crontab
    echo "" >> /etc/cron.d/backup_postgres_crontab
    service cron restart
    echo "PostgreSQL automatic backup schedule: ${POSTGRES_BACKUP_SCHEDULE}"

fi
