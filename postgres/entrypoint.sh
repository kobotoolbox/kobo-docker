#!/usr/bin/env bash
# set -e

export POSTGRES_BIN_DIRECTORY=/usr/lib/postgresql/9.5/bin/
export POSTGRES_REPO=/var/lib/postgresql
export POSTGRES_BIN=${POSTGRES_BIN_DIRECTORY}/postgres
export POSTGRES_DATA_DIR=${POSTGRES_REPO}/data
export POSTGRES_CONFIG_FILE=${POSTGRES_DATA_DIR}/postgresql.conf
export POSTGRES_CLIENT_AUTH_FILE=${POSTGRES_DATA_DIR}/pg_hba.conf
export POSTGRES_BACKUPS_DIR=/srv/backups
export POSTGRES_LOGS_DIR=/srv/logs
export KOBO_DOCKER_SCRIPTS_DIR=/kobo-docker-scripts

echo "Copying init scripts ..."
cp $KOBO_DOCKER_SCRIPTS_DIR/shared/init_* /docker-entrypoint-initdb.d/
cp $KOBO_DOCKER_SCRIPTS_DIR/$KOBO_POSTGRES_DB_SERVER_ROLE/init_* /docker-entrypoint-initdb.d/


# Restore permissions
if [ ! -d $POSTGRES_LOGS_DIR ]; then
    mkdir -p $POSTGRES_LOGS_DIR
fi

if [ ! -d $POSTGRES_BACKUPS_DIR ]; then
    mkdir -p $POSTGRES_BACKUPS_DIR
fi

chown -R postgres:postgres $POSTGRES_LOGS_DIR
chown -R postgres:postgres $POSTGRES_BACKUPS_DIR

# if file exists. Container has already boot once
if [ -f "$POSTGRES_DATA_DIR/kobo_first_run" ]; then
    /bin/bash $KOBO_DOCKER_SCRIPTS_DIR/shared/init_02_set_postgres_config.sh

    # Update PostGIS as background task.
    # FIXME There should be a better way to run this script
    sleep 30 && update-postgis.sh &

elif [ "$KOBO_POSTGRES_DB_SERVER_ROLE" == "slave" ]; then
    # Because slave is a replica. This script has already been run on master
    echo "Disabling postgis update..."
    mv /docker-entrypoint-initdb.d/postgis.sh /docker-entrypoint-initdb.d/postgis.sh.disabled
fi


BASH_PATH=$(which bash)
$BASH_PATH $KOBO_DOCKER_SCRIPTS_DIR/toggle-backup-activation.sh

echo "Launching official entrypoint..."
# `exec` here is important to pass signals to the database server process;
# without `exec`, the server will be terminated abruptly with SIGKILL (see #276)
exec /bin/bash /docker-entrypoint.sh postgres
