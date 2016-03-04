#!/bin/bash
set -e

echo 'Waiting for container `kpi`.'
dockerize -timeout=20s -wait ${KPI_PORT}
echo 'Container `kpi` up.'

echo 'Waiting for `kpi` uWSGI service.'
# Beware the following hardcoded port number...
until $(curl kpi:8000 2> /dev/null) || [[ $? == 52 ]]; do
    sleep 1
done
echo '`kpi` uWSGI service ready.'
