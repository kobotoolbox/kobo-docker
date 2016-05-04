#!/bin/bash
set -e

echo 'Waiting for container `psql`.'
dockerize -timeout=20s -wait ${PSQL_PORT}
echo 'Container `psql` up.'

echo 'Waiting for Postgres service.'
# TODO: There must be a way to confirm Postgres is serving without the resulting "incomplete startup packet" warning in the logs.
KOBO_PSQL_DB_NAME=${KOBO_PSQL_DB_NAME:-"kobotoolbox"}
KOBO_PSQL_DB_USER=${KOBO_PSQL_DB_USER:-"kobo"}
until pg_isready -d "${KOBO_PSQL_DB_NAME}" -h psql -U "${KOBO_PSQL_DB_USER}"; do
    sleep 1
done
echo 'Postgres service ready.'
