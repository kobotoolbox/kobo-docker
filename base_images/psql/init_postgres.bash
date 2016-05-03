#!/bin/bash
set -e

KOBO_PSQL_DB_NAME=${KOBO_PSQL_DB_NAME:-"kobotoolbox"}
KOBO_PSQL_DB_USER=${KOBO_PSQL_DB_USER:-"kobo"}
KOBO_PSQL_DB_PASS=${KOBO_PSQL_DB_PASS:-"kobo"}

PSQL_BIN=/usr/lib/postgresql/9.4/bin/postgres
PSQL_CONFIG_FILE=/etc/postgresql/9.4/main/postgresql.conf
PSQL_DATA=/srv/db

if [[ "$(cat /srv/db/PG_VERSION)" == '9.3' ]]; then
    echo 'Existing Postgres 9.3 database detected. Preparing to upgrade it.'
    echo 'Installing Postgres 9.3 and dependencies.'
    apt-get -qq update
    apt-get install -qqy postgresql-9.3-postgis-2.1
    echo 'Removing automatically-installed 9.3 default database.'
    pg_dropcluster 9.3 main
    echo 'Moving old database contents to `/srv/db_9.3/`.'
    mkdir -p /srv/db_9.3
    chmod --reference=/srv/db /srv/db_9.3
    chown --reference=/srv/db /srv/db_9.3
    mv /srv/db/* /srv/db_9.3/
    echo 'Setting 9.3 to manage the old database.'
    mv /etc/postgresql/9.4 /etc/postgresql/9.3
    sed -i 's/9\.4/9\.3/g' /etc/postgresql/9.3/main/postgresql.conf
    sed -i 's/\/srv\/db/\/srv\/db_9.3/g' /etc/postgresql/9.3/main/postgresql.conf
    echo 'Executing database upgrade.'
    pg_upgradecluster 9.3 main /srv/db
    pg_ctlcluster 9.4 main stop
    echo 'Database upgrade complete.'
fi

# prepare data directory and initialize database if necessary
[ -d $PSQL_DATA ] || mkdir -p $PSQL_DATA
chown -R postgres:postgres $PSQL_DATA
[ $(cd $PSQL_DATA && ls -lA | wc -l) -ne 1 ] || \
    sudo -u postgres /usr/lib/postgresql/9.4/bin/initdb -D /srv/db -E utf-8 --locale=en_US.UTF-8

PSQL_SINGLE="sudo -u postgres $PSQL_BIN --single --config-file=$PSQL_CONFIG_FILE"

$PSQL_SINGLE <<< "CREATE USER $KOBO_PSQL_DB_USER WITH SUPERUSER;" > /dev/null
# $PSQL_SINGLE <<< "CREATE USER $KOBO_PSQL_DB_USER;" > /dev/null
$PSQL_SINGLE <<< "ALTER USER $KOBO_PSQL_DB_USER WITH PASSWORD '$KOBO_PSQL_DB_PASS';" > /dev/null
$PSQL_SINGLE <<< "CREATE DATABASE $KOBO_PSQL_DB_NAME OWNER $KOBO_PSQL_DB_USER" > /dev/null

echo 'Initializing PostGIS.'
pg_ctlcluster 9.4 main start -o '-c listen_addresses=""' # Temporarily start Postgres for local connections only.
sudo -u postgres psql ${KOBO_PSQL_DB_NAME} -c "create extension postgis; create extension postgis_topology" \
    || true # FIXME: Workaround so this script doesn't exit if PostGIS has already been initialized.
pg_ctlcluster 9.4 main stop
