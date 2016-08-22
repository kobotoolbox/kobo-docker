#!/bin/bash
set -e

echo 'Waiting for container `kpi`.'
dockerize -timeout=60s -wait ${KPI_PORT}
echo 'Container `kpi` up.'

echo 'Waiting for `kpi` web service.'
# NOTE: Beware the following hardcoded port number...
until curl kpi:8000 &> /dev/null || [[ "$?" == '52' ]]; do
    sleep 1
done
echo '`kpi` web service ready.'
