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

    # To use S3 as storage, AWS access key, secret key and bucket name must filled up
    USE_S3=1
    TRUE=1
    FALSE=0

    # Add only non-empty variable to cron tasks
    if [[ -n "${AWS_ACCESS_KEY_ID}" ]]; then
        echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> /etc/cron.d/backup_postgres_crontab
    else
        USE_S3=$FALSE
    fi

    if [[ -n "${AWS_SECRET_ACCESS_KEY}" ]]; then
        echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" >> /etc/cron.d/backup_postgres_crontab
    else
        USE_S3=$FALSE
    fi

    if [[ -n "${BACKUP_AWS_STORAGE_BUCKET_NAME}" ]]; then
        echo "BACKUP_AWS_STORAGE_BUCKET_NAME=${BACKUP_AWS_STORAGE_BUCKET_NAME}" >> /etc/cron.d/backup_postgres_crontab
    else
        USE_S3=$FALSE
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

    if [[ ${USE_S3} -eq "$TRUE" ]]; then
        apt-get install -y curl python3-pip libffi-dev --quiet=2 > /dev/null
        # Update pip to latest version compatible with Python 3.5
        curl https://bootstrap.pypa.io/pip/3.5/get-pip.py -o /tmp/get-pip.py
        python3 /tmp/get-pip.py

        if [[ ${USE_WAL_E} -eq "$TRUE" ]]; then
            echo "Installing envdir and WAL-E for PostgreSQL backup on S3..."
            apt-get install -y libevent-dev daemontools lzop pv --quiet=2 > /dev/null
            python3 -m pip install --quiet wal-e aws

            # Find EC2 region
            EC2_AVAIL_ZONE=$(/usr/bin/curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone) #AWS zone
            EC2_REGION=$(echo $EC2_AVAIL_ZONE | sed 's/[a-z]$//') #AWS region

            # Add envdir for Wal-e backup
            mkdir -p ${POSTGRES_DATA_DIR}/wal-e.d/env
            echo "${AWS_SECRET_ACCESS_KEY}" > ${POSTGRES_DATA_DIR}/wal-e.d/env/AWS_SECRET_ACCESS_KEY
            echo "${AWS_ACCESS_KEY_ID}" > ${POSTGRES_DATA_DIR}/wal-e.d/env/AWS_ACCESS_KEY_ID
            echo "s3://${BACKUP_AWS_STORAGE_BUCKET_NAME}/postgres/" > ${POSTGRES_DATA_DIR}/wal-e.d/env/WALE_S3_PREFIX
            echo "${EC2_REGION}" > ${POSTGRES_DATA_DIR}/wal-e.d/env/AWS_REGION
            chown -R postgres:postgres ${POSTGRES_DATA_DIR}/wal-e.d

            # Add crontab Wal-e backup to S3
            CRON_CMD="${POSTGRES_BACKUP_SCHEDULE}  postgres   envdir ${POSTGRES_DATA_DIR}/wal-e.d/env/ /usr/local/bin/wal-e backup-push ${POSTGRES_DATA_DIR} > /srv/logs/backup.log 2>&1"
            
        else
            echo "Installing virtualenv for PostgreSQL backup on S3..."
            python3 -m pip install --upgrade --quiet virtualenv
            counter=1
            max_retries=3
            # Under certain circumstances a race condition occurs. Virtualenv creation
            # fails because python cannot find `wheel` package folder
            # e.g. `FileNotFoundError: [Errno 2] No such file or directory: '/root/.local/share/virtualenv/wheel/3.5/embed/1/wheel.json'`
            until $(virtualenv --quiet -p /usr/bin/python3 /tmp/backup-virtualenv > /dev/null)
            do
                [[ "$counter" -eq "$max_retries" ]] && echo "Virtual environment creation failed!" && exit 1
                ((counter++))
            done
            . /tmp/backup-virtualenv/bin/activate
            pip install --quiet humanize smart-open==1.7.1
            pip install --quiet boto
            deactivate

            CRON_CMD="${POSTGRES_BACKUP_SCHEDULE}  root    /usr/bin/nice -n 19 /usr/bin/ionice -c2 -n7 /tmp/backup-virtualenv/bin/python /kobo-docker-scripts/backup-to-s3.py > /srv/logs/backup.log 2>&1"
        fi
    else
        CRON_CMD="${POSTGRES_BACKUP_SCHEDULE}  root    /usr/bin/nice -n 19 /usr/bin/ionice -c2 -n7 /bin/bash /kobo-docker-scripts/backup-to-disk.bash > /srv/logs/backup.log 2>&1"
    fi

    # Should we first validate the schedule e.g. with `chkcrontab`?
    echo "${CRON_CMD}" >> /etc/cron.d/backup_postgres_crontab
    echo "" >> /etc/cron.d/backup_postgres_crontab
    service cron restart
    echo "PostgreSQL automatic backup schedule: ${POSTGRES_BACKUP_SCHEDULE}"

fi
