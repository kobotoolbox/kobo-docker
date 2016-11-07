#!/bin/bash
set -e

KOBO_POSTGRES_DB_NAME=${KOBO_POSTGRES_DB_NAME:-"kobotoolbox"}
KOBO_POSTGRES_USER=${KOBO_POSTGRES_USER:-"kobo"}
KOBO_POSTGRES_PASSWORD=${KOBO_POSTGRES_PASSWORD:-"kobo"}

POSTGRES_BIN=/usr/lib/postgresql/9.4/bin/postgres
POSTGRES_CONFIG_FILE=/etc/postgresql/9.4/main/postgresql.conf
POSTGRES_CLUSTER_DIR=/srv/db

if [[ "$(ls -ld "${POSTGRES_CLUSTER_DIR}" | awk '{print $3}')" != 'postgres' ]]; then
    echo 'Restoring ownership of Postgres cluster data directory.'
    chown -R postgres:postgres "${POSTGRES_CLUSTER_DIR}"
fi
echo 'Restoring permissions of Postgres cluster data directory.'
chmod -R 700 "${POSTGRES_CLUSTER_DIR}"

if [[ "$(cat ${POSTGRES_CLUSTER_DIR}/PG_VERSION)" == '9.3' ]]; then
    echo 'Existing Postgres 9.3 database cluster detected. Preparing to upgrade it.'
    echo 'Installing Postgres 9.3 and dependencies.'
    apt-get -qq update
    apt-get install -qqy postgresql-9.3-postgis-2.2
    echo 'Removing Postgres 9.3 automatically-installed default cluster.'
    pg_dropcluster 9.3 main
    echo "Moving old cluster contents to \`${POSTGRES_CLUSTER_DIR}_9.3/\` (without deleting \`${POSTGRES_CLUSTER_DIR}\`)."
    mkdir -p "${POSTGRES_CLUSTER_DIR}"_9.3
    chmod 700 "${POSTGRES_CLUSTER_DIR}_9.3"
    chown postgres:postgres "${POSTGRES_CLUSTER_DIR}_9.3"
    # Arcane incantation alert: move all files including hidden ones. See: http://superuser.com/a/62192/160413.
    find "${POSTGRES_CLUSTER_DIR}" -mindepth 1 -maxdepth 1 -exec mv -t"${POSTGRES_CLUSTER_DIR}_9.3" -- {} +
    echo 'Setting Postgres 9.3 to manage the old cluster.'
    mv /etc/postgresql/9.4 /etc/postgresql/9.3
    sed -i 's/9\.4/9\.3/g' /etc/postgresql/9.3/main/postgresql.conf
    sed -i 's/\/srv\/db/\/srv\/db_9.3/g' /etc/postgresql/9.3/main/postgresql.conf
    echo "Creating \`pg_restore\`-compatible, compressed backup of the old \`${KOBO_POSTGRES_DB_NAME}\` database."
    TIME_STAMP="$(date +%Y.%m.%d.%H_%M_%S)"
    pg_ctlcluster 9.3 main start -o '-c listen_addresses=""' # Temporarily start Postgres for local connections only.
    su postgres -c "pg_dump -Z1 -Fc ${KOBO_POSTGRES_DB_NAME}" > "/srv/backups/${TIME_STAMP}__${KOBO_POSTGRES_DB_NAME}.pg_restore"
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
    su postgres -c "usr/lib/postgresql/9.4/bin/initdb -D ${POSTGRES_CLUSTER_DIR} -E utf-8 --locale=en_US.UTF-8"

su postgres -c "${POSTGRES_BIN} --single --config-file=${POSTGRES_CONFIG_FILE}" <<< "CREATE USER $KOBO_POSTGRES_USER WITH SUPERUSER;" > /dev/null
su postgres -c "${POSTGRES_BIN} --single --config-file=${POSTGRES_CONFIG_FILE}" <<< "ALTER USER $KOBO_POSTGRES_USER WITH PASSWORD '$KOBO_POSTGRES_PASSWORD';" > /dev/null
su postgres -c "${POSTGRES_BIN} --single --config-file=${POSTGRES_CONFIG_FILE}" <<< "CREATE DATABASE $KOBO_POSTGRES_DB_NAME OWNER $KOBO_POSTGRES_USER" > /dev/null

echo 'Initializing PostGIS.'
pg_ctlcluster 9.4 main start -o '-c listen_addresses=""' # Temporarily start Postgres for local connections only.
su postgres -c "psql ${KOBO_POSTGRES_DB_NAME} -c \"create extension if not exists postgis; create extension if not exists postgis_topology\""
pg_ctlcluster 9.4 main stop

source /etc/profile
rm -f /etc/cron.d/backup_postgres_crontab
if [[ -z "${POSTGRES_BACKUP_SCHEDULE}" ]]; then
    echo 'Postgres automatic backups disabled.'
else
    # Should we first validate the schedule e.g. with `chkcrontab`?
    cat "/srv/backup_postgres_crontab.envsubst" | envsubst > /etc/cron.d/backup_postgres_crontab
    echo "Postgres automatic backup schedule: ${POSTGRES_BACKUP_SCHEDULE}"
fi

