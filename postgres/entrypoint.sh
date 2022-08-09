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
    # Recreate config first
    bash $KOBO_DOCKER_SCRIPTS_DIR/shared/init_02_set_postgres_config.sh

    if [ "$KOBO_POSTGRES_DB_SERVER_ROLE" == "primary" ]; then
        # Start server locally.
        su - postgres -c "$(command -v pg_ctl) -D \"$PGDATA\" -o \"-c listen_addresses='127.0.0.1'\" -w start"
        until pg_isready -h 127.0.0.1 ; do
            sleep 1
        done
        # Update users if needed
        bash $KOBO_DOCKER_SCRIPTS_DIR/shared/upsert_users.sh
        # Update PostGIS extension
        update-postgis.sh
        # Stop server
        su - postgres -c "$(command -v pg_ctl) -D \"$PGDATA\" -m fast -w stop"
    fi

elif [ "$KOBO_POSTGRES_DB_SERVER_ROLE" == "secondary" ]; then
    # Because secondary is a replica. This script has already been run on primary server
    echo "Disabling postgis update..."
    mv /docker-entrypoint-initdb.d/10_postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh.disabled
fi


# Send backup installation process in background to avoid blocking PostgreSQL startup
bash $KOBO_DOCKER_SCRIPTS_DIR/toggle-backup-activation.sh &

echo "Launching official entrypoint..."
# `exec` here is important to pass signals to the database server process;
# without `exec`, the server will be terminated abruptly with SIGKILL (see #276)
exec bash /usr/local/bin/docker-entrypoint.sh postgres
