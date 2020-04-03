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

if [ ! -d $POSTGRES_LOGS_DIR ]; then
    mkdir -p $POSTGRES_LOGS_DIR
fi

if [ ! -d $POSTGRES_BACKUPS_DIR ]; then
    mkdir -p $POSTGRES_BACKUPS_DIR
fi

# Restore permissions
chown -R postgres:postgres $POSTGRES_LOGS_DIR
chown -R postgres:postgres $POSTGRES_BACKUPS_DIR

# if file exists. Container has already boot once
if [ -f "$POSTGRES_DATA_DIR/kobo_first_run" ]; then
    # Start server locally.
    su - postgres -c "/usr/lib/postgresql/9.5/bin/pg_ctl -D \"$PGDATA\" -o \"-c listen_addresses='127.0.0.1'\" -w start"
    until pg_isready -h 127.0.0.1 ; do
        sleep 1
    done

    /bin/bash $KOBO_DOCKER_SCRIPTS_DIR/shared/init_02_set_postgres_config.sh
    /bin/bash $KOBO_DOCKER_SCRIPTS_DIR/shared/upsert_users.sh
    update-postgis.sh

    # Stop server
    su - postgres -c "/usr/lib/postgresql/9.5/bin/pg_ctl -D \"$PGDATA\" -m fast -w stop"

elif [ "$KOBO_POSTGRES_DB_SERVER_ROLE" == "slave" ]; then
    # Because slave is a replica. This script has already been run on master
    echo "Disabling postgis update..."
    mv /docker-entrypoint-initdb.d/postgis.sh /docker-entrypoint-initdb.d/postgis.sh.disabled
fi


BASH_PATH=$(command -v bash)
$BASH_PATH $KOBO_DOCKER_SCRIPTS_DIR/toggle-backup-activation.sh

echo "Launching official entrypoint..."
/bin/bash /docker-entrypoint.sh postgres
