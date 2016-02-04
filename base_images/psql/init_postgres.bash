#!/bin/bash
set -e

KOBO_PSQL_DB_NAME=${KOBO_PSQL_DB_NAME:-"kobotoolbox"}
KOBO_PSQL_DB_USER=${KOBO_PSQL_DB_USER:-"kobo"}
KOBO_PSQL_DB_PASS=${KOBO_PSQL_DB_PASS:-"kobo"}

PSQL_BIN=/usr/lib/postgresql/9.3/bin/postgres
PSQL_CONFIG_FILE=/etc/postgresql/9.3/main/postgresql.conf
PSQL_DATA=/srv/db

# prepare data directory and initialize database if necessary
[ -d $PSQL_DATA ] || mkdir -p $PSQL_DATA
chown -R postgres:postgres $PSQL_DATA
[ $(cd $PSQL_DATA && ls -lA | wc -l) -ne 1 ] || \
    sudo -u postgres /usr/lib/postgresql/9.3/bin/initdb -D /srv/db -E utf-8 --locale=en_US.UTF-8

PSQL_SINGLE="sudo -u postgres $PSQL_BIN --single --config-file=$PSQL_CONFIG_FILE"

$PSQL_SINGLE <<< "CREATE USER $KOBO_PSQL_DB_USER WITH SUPERUSER;" > /dev/null
# $PSQL_SINGLE <<< "CREATE USER $KOBO_PSQL_DB_USER;" > /dev/null
$PSQL_SINGLE <<< "ALTER USER $KOBO_PSQL_DB_USER WITH PASSWORD '$KOBO_PSQL_DB_PASS';" > /dev/null
$PSQL_SINGLE <<< "CREATE DATABASE $KOBO_PSQL_DB_NAME OWNER $KOBO_PSQL_DB_USER" > /dev/null

echo 'Initializing PostGIS.'
pg_ctlcluster 9.3 main start
sudo -u postgres psql ${KOBO_PSQL_DB_NAME} -c "create extension postgis; create extension postgis_topology"
pg_ctlcluster 9.3 main stop
