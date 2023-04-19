#!/bin/bash
set -e

echo 'Waiting for container `postgres`.'
wait-for-it -t 20 -h $POSTGRES_HOST -p $POSTGRES_PORT
echo 'Container `postgres` up.'

echo 'Waiting for Postgres service.'
# TODO: There must be a way to confirm Postgres is serving without the resulting "incomplete startup packet" warning in the logs.
POSTGRES_DB="${POSTGRES_DB:-kobotoolbox}"
POSTGRES_USER="${POSTGRES_USER:-kobo}"
export PGPASSWORD="${POSTGRES_PASSWORD:-kobo}"
until pg_isready -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}"; do
    sleep 1
done

source /etc/profile

echo "Postgres service running; ensuring ${POSTGRES_DB} database exists and has PostGIS extensions..."
psql -d postgres -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" <<EOF
CREATE DATABASE "$POSTGRES_DB" OWNER "$POSTGRES_USER";
\c "$POSTGRES_DB"
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
EOF
echo "Postgres database ${POSTGRES_DB} ready for use!"
