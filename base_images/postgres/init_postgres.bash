#!/bin/bash
set -e

KOBO_POSTGRES_DB_NAME=${KOBO_POSTGRES_DB_NAME:-"kobotoolbox"}
KOBO_POSTGRES_USER=${KOBO_POSTGRES_USER:-"kobo"}
KOBO_POSTGRES_PASSWORD=${KOBO_POSTGRES_PASSWORD:-"kobo"}

POSTGRES_BIN=/usr/lib/postgresql/9.4/bin/postgres
POSTGRES_CONFIG_FILE=/etc/postgresql/9.4/main/postgresql.conf
POSTGRES_CLUSTER_DIR=/srv/db

if [[ "$(cat ${POSTGRES_CLUSTER_DIR}/PG_VERSION)" == '9.3' ]]; then
    echo 'Existing Postgres 9.3 database cluster detected. Preparing to upgrade it.'
    echo 'Installing Postgres 9.3 and dependencies.'
    apt-get -qq update
    apt-get install -qqy postgresql-9.3-postgis-2.1
    echo 'Removing Postgres 9.3 automatically-installed default cluster.'
    pg_dropcluster 9.3 main
    echo "Moving old cluster contents to \`${POSTGRES_CLUSTER_DIR}_9.3/\`."
    mkdir -p "${POSTGRES_CLUSTER_DIR}"_9.3
    chmod --reference="${POSTGRES_CLUSTER_DIR}" "${POSTGRES_CLUSTER_DIR}_9.3"
    chown --reference="${POSTGRES_CLUSTER_DIR}" "${POSTGRES_CLUSTER_DIR}_9.3"
    mv "${POSTGRES_CLUSTER_DIR}/*" "${POSTGRES_CLUSTER_DIR}_9.3/"
    echo 'Setting Postgres 9.3 to manage the old cluster.'
    mv /etc/postgresql/9.4 /etc/postgresql/9.3
    sed -i 's/9\.4/9\.3/g' /etc/postgresql/9.3/main/postgresql.conf
    sed -i 's/\/srv\/db/\/srv\/db_9.3/g' /etc/postgresql/9.3/main/postgresql.conf
    echo "Creating \`pg_restore\`-compatible, compressed backup of the old \`${KOBO_POSTGRES_DB_NAME}\` database."
    TIME_STAMP="$(date +%Y.%m.%d.%H_%M_%S)"
    pg_ctlcluster 9.3 main start -o '-c listen_addresses=""' # Temporarily start Postgres for local connections only.
    sudo -u postgres pg_dump -Z1 -Fc "${KOBO_POSTGRES_DB_NAME}" > "/srv/backups/${TIME_STAMP}__${KOBO_POSTGRES_DB_NAME}.pg_restore"
    pg_ctlcluster 9.3 main stop
    echo 'Executing cluster upgrade (without allowing remote connections).'
    pg_upgradecluster -o '-c listen_addresses=""' -O '-c listen_addresses=""' 9.3 main "${POSTGRES_CLUSTER_DIR}"
    pg_ctlcluster 9.4 main stop
    echo 'Removing old cluster.'
    pg_dropcluster 9.3 main
    echo 'Database cluster upgrade complete.'
fi

# prepare data directory and initialize database if necessary
[ -d $POSTGRES_CLUSTER_DIR ] || mkdir -p $POSTGRES_CLUSTER_DIR
chown -R postgres:postgres $POSTGRES_CLUSTER_DIR
[ $(cd $POSTGRES_CLUSTER_DIR && ls -lA | wc -l) -ne 1 ] || \
    sudo -u postgres /usr/lib/postgresql/9.4/bin/initdb -D ${POSTGRES_CLUSTER_DIR} -E utf-8 --locale=en_US.UTF-8

POSTGRES_SINGLE_USER="sudo -u postgres $POSTGRES_BIN --single --config-file=$POSTGRES_CONFIG_FILE"

$POSTGRES_SINGLE_USER <<< "CREATE USER $KOBO_POSTGRES_USER WITH SUPERUSER;" > /dev/null
$POSTGRES_SINGLE_USER <<< "ALTER USER $KOBO_POSTGRES_USER WITH PASSWORD '$KOBO_POSTGRES_PASSWORD';" > /dev/null
$POSTGRES_SINGLE_USER <<< "CREATE DATABASE $KOBO_POSTGRES_DB_NAME OWNER $KOBO_POSTGRES_USER" > /dev/null

echo 'Initializing PostGIS.'
pg_ctlcluster 9.4 main start -o '-c listen_addresses=""' # Temporarily start Postgres for local connections only.
sudo -u postgres psql ${KOBO_POSTGRES_DB_NAME} -c "create extension postgis; create extension postgis_topology" \
    || true # FIXME: Workaround so this script doesn't exit if PostGIS has already been initialized.
pg_ctlcluster 9.4 main stop
