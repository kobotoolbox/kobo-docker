#!/usr/bin/env bash
# set -e

export POSTGRES_BIN_DIRECTORY=/usr/lib/postgresql/9.5/bin/
export POSTGRES_REPO=/var/lib/postgresql
export POSTGRES_BIN=${POSTGRES_BIN_DIRECTORY}/postgres
export POSTGRES_DATA_DIR=${POSTGRES_REPO}/data
export POSTGRES_CONFIG_FILE=${POSTGRES_DATA_DIR}/postgresql.conf
export POSTGRES_CLIENT_AUTH_FILE=${POSTGRES_DATA_DIR}/pg_hba.conf
export POSTGRES_BACKUPS_DIR=/srv/backups
export KOBO_DOCKER_SCRIPTS_DIR=/kobo-docker-scripts

echo "Copying init scripts..."
cp $KOBO_DOCKER_SCRIPTS_DIR/shared/init_* /docker-entrypoint-initdb.d/
cp $KOBO_DOCKER_SCRIPTS_DIR/$KOBO_POSTGRES_DB_SERVER_ROLE/init_* /docker-entrypoint-initdb.d/


if [ -f "$POSTGRES_DATA_DIR/.first_run" ]; then
    /bin/bash $KOBO_DOCKER_SCRIPTS_DIR/shared/init_00_set_postgres_config.sh
fi

echo "Launching official entrypoint..."
/bin/bash /docker-entrypoint.sh postgres