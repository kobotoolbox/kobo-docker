#!/usr/bin/env bash

if [ ! -f "$POSTGRES_CONFIG_FILE.orig" ]; then
    echo "Let's keep a copy of current configuration file!"
    cp $POSTGRES_CONFIG_FILE "$POSTGRES_CONFIG_FILE.orig"
fi

echo "Applying new configuration..."
cp $KOBO_DOCKER_SCRIPTS_DIR/shared/postgres.conf $POSTGRES_CONFIG_FILE

if [ ! -f "$POSTGRES_CLIENT_AUTH_FILE.orig" ]; then
    echo "Let's keep a copy of current client authentication configuration file!"
    cp $POSTGRES_CLIENT_AUTH_FILE "$POSTGRES_CLIENT_AUTH_FILE.orig"
fi

echo "Applying new client authentication configuration file..."
cp $KOBO_DOCKER_SCRIPTS_DIR/shared/pg_hba.conf "$POSTGRES_CLIENT_AUTH_FILE"

KOBO_POSTGRES_REMOTE_INSTANCE=$([[ "$KOBO_POSTGRES_DB_SERVER_ROLE" != "master" ]] && echo $KOBO_POSTGRES_MASTER_ENDPOINT || echo $KOBO_POSTGRES_SLAVE_ENDPOINT)

echo "Creating hg_hba config file..."
sed -i "s/KOBO_POSTGRES_REPLICATION_USER/${KOBO_POSTGRES_REPLICATION_USER//\"/}/g" "$POSTGRES_CLIENT_AUTH_FILE"
sed -i "s~KOBO_POSTGRES_REMOTE_INSTANCE~${KOBO_POSTGRES_REMOTE_INSTANCE//\"/}~g" "$POSTGRES_CLIENT_AUTH_FILE"

#chown -R postgres:postgres $POSTGRES_CONFIG_FILE
#chown -R postgres:postgres $POSTGRES_CLIENT_AUTH_FILE
