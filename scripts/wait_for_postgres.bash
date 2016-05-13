#!/bin/bash
set -e

echo 'Waiting for container `psql`.'
dockerize -timeout=60s -wait ${PSQL_PORT}
echo 'Container `psql` up.'

echo 'Waiting for Postgres service.'
# FIXME: There must be a way to confirm Postgres is serving without these details or the resulting "incomplete startup packet" warning from Postgres.
KOBO_PSQL_DB_NAME=${KOBO_PSQL_DB_NAME:-"kobotoolbox"}
KOBO_PSQL_DB_USER=${KOBO_PSQL_DB_USER:-"kobo"}
KOBO_PSQL_DB_PASS=${KOBO_PSQL_DB_PASS:-"kobo"}
until $(PGPASSWORD="${KOBO_PSQL_DB_PASS}" psql -d ${KOBO_PSQL_DB_NAME} -h psql -U ${KOBO_PSQL_DB_USER} -c '' 2> /dev/null); do
    sleep 1
done
echo 'Postgres service ready.'
