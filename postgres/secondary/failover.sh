#!/usr/bin/env bash

POSTGRES_BIN_DIRECTORY=/usr/lib/postgresql/9.5/bin/
POSTGRES_REPO=/var/lib/postgresql
POSTGRES_BIN=${POSTGRES_BIN_DIRECTORY}/postgres
POSTGRES_DATA_DIR=${POSTGRES_REPO}/data
POSTGRES_CONFIG_FILE=${POSTGRES_DATA_DIR}/postgresql.conf
POSTGRES_PERMISSION_FILE=${POSTGRES_DATA_DIR}/pg_hba.conf
POSTGRES_BACKUPS_DIR=/srv/backups
POSTGRES_FAILOVER_TRIGGER_FILE=${POSTGRES_DATA_DIR}/failover.trigger


IS_PRIMARY_ALIVE=$((echo > /dev/tcp/${KOBO_POSTGRES_PRIMARY_ENDPOINT//\"/}/${POSTGRES_PORT}) >/dev/null 2>&1 && echo "1" || echo "0")
UNHEALTHY_FILE="/tmp/${KOBO_POSTGRES_PRIMARY_ENDPOINT//\"/}-unhealthy-count.txt"

if [ "$IS_PRIMARY_ALIVE" == "1" ]; then
    echo "Primary is alive, nothing to do"
    rm -rf $UNHEALTHY_FILE
else
    UNHEALTHY_COUNT=0

    if [ -f "$UNHEALTHY_FILE" ]; then
        UNHEALTHY_COUNT=$(cat $UNHEALTHY_FILE)
    fi

    UNHEALTHY_COUNT=$(($UNHEALTHY_COUNT + 1))

    echo "UNHEALTHY_COUNT: $UNHEALTHY_COUNT"

    if [ "$UNHEALTHY_COUNT" -ge "$KOBO_THRESHOLD_FAILOVER" ]; then

        if [ ! -f "$POSTGRES_FAILOVER_TRIGGER_FILE" ]; then
            echo "Starting failover process..."
            su postgres -c "touch $POSTGRES_FAILOVER_TRIGGER_FILE"
        else
            echo "Failover process has already been launched..."
        fi
    else
        echo $UNHEALTHY_COUNT > $UNHEALTHY_FILE
    fi
fi
