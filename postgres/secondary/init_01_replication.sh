#!/usr/bin/env bash

echo "Creating pgpass file..."
echo "${KOBO_POSTGRES_PRIMARY_ENDPOINT}:${POSTGRES_PORT}:*:${KOBO_POSTGRES_REPLICATION_USER}:${KOBO_POSTGRES_REPLICATION_PASSWORD}" | tr -d '"' > "$POSTGRES_REPO/.pgpass"
chown postgres:postgres "$POSTGRES_REPO/.pgpass"
chmod 600 "$POSTGRES_REPO/.pgpass"


echo "Let's the primary start, wait for 30s"
echo "Primary should be: $KOBO_POSTGRES_PRIMARY_ENDPOINT"
sleep 30

IS_OPENED=$((echo > /dev/tcp/${KOBO_POSTGRES_PRIMARY_ENDPOINT//\"/}/${POSTGRES_PORT}) >/dev/null 2>&1 && echo "1" || echo "0")

if [ "$IS_OPENED" == "1" ]; then

    # Shutdown postgres before importing primary data
    PGUSER="${PGUSER:-postgres}" pg_ctl -D "$PGDATA" -m fast -w stop

    echo "Deleting database directory..."
    rm -rf $POSTGRES_DATA_DIR/*
    echo "Cloning primary data..."
    echo ${KOBO_POSTGRES_REPLICATION_PASSWORD} | PGUSER="${PGUSER:-postgres}" PGPASSFILE=${POSTGRES_REPO//\"/}/.pgpass pg_basebackup -h ${KOBO_POSTGRES_PRIMARY_ENDPOINT//\"/} --port=${POSTGRES_PORT//\"/} -D ${POSTGRES_DATA_DIR//\"/} -U ${KOBO_POSTGRES_REPLICATION_USER//\"/} -v -P --xlog -c fast -W
    echo "Primary data cloned!"

    POSTGRES_RECOVERY_FILE=${POSTGRES_DATA_DIR}/recovery.conf

    echo "Creation recovery configuration file..."
    cp $KOBO_DOCKER_SCRIPTS_DIR/secondary/recovery.conf ${POSTGRES_RECOVERY_FILE}
    sed -i "s/POSTGRES_PORT/${POSTGRES_PORT//\"/}/g" "$POSTGRES_RECOVERY_FILE"
    sed -i "s/KOBO_POSTGRES_PRIMARY_ENDPOINT/${KOBO_POSTGRES_PRIMARY_ENDPOINT//\"/}/g" "$POSTGRES_RECOVERY_FILE"
    sed -i "s/KOBO_POSTGRES_REPLICATION_USER/${KOBO_POSTGRES_REPLICATION_USER//\"/}/g" "$POSTGRES_RECOVERY_FILE"
    sed -i "s/KOBO_POSTGRES_REPLICATION_PASSWORD/${KOBO_POSTGRES_REPLICATION_PASSWORD//\"/}/g" "$POSTGRES_RECOVERY_FILE"
    sed -i "s~POSTGRES_DATA_DIR~${POSTGRES_DATA_DIR//\"/}~g" "$POSTGRES_RECOVERY_FILE"

    # Restart postgres the same way it was by docker-entrypoint.sh
    PGUSER="${PGUSER:-postgres}" pg_ctl -D "$PGDATA" -o "-c listen_addresses='localhost'" -w start

    echo "Done!"
else
    echo "ERROR: NO PRIMARY FOUND"
fi
