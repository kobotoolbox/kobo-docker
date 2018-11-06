#!/bin/bash
set -e

echo 'Waiting for container `postgres`.'
dockerize -timeout=20s -wait tcp://${POSTGRES_HOST}:${POSTGRES_PORT}
echo 'Container `postgres` up.'

echo 'Waiting for Postgres service.'
# TODO: There must be a way to confirm Postgres is serving without the resulting "incomplete startup packet" warning in the logs.
POSTGRES_DB_NAME="${POSTGRES_DB_NAME:-kobotoolbox}"
POSTGRES_USER="${POSTGRES_USER:-kobo}"
until pg_isready -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}"; do
    sleep 1
done
echo "Postgres service running; ensuring ${POSTGRES_DB_NAME} database exists and has PostGIS extensions..."
PGPASSWORD="${POSTGRES_PASSWORD:-kobo}" psql \
    -d postgres -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" <<EOF
CREATE DATABASE "$POSTGRES_DB_NAME" OWNER "$POSTGRES_USER";
\c "$POSTGRES_DB_NAME"
CREATE EXTENSION IF NOT EXISTS postgis; CREATE EXTENSION IF NOT EXISTS postgis_topology;
EOF
echo "Postgres database ${POSTGRES_DB_NAME} ready for use!"
