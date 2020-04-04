#!/bin/bash
set -e

echo 'Waiting for container `kpi`.'
dockerize -timeout=300s -wait tcp://{KPI_HOST}:${KPI_PORT}
echo 'Container `kpi` up.'

echo 'Waiting for `kpi` web service.'
until curl {KPI_HOST}:${KPI_PORT} &> /dev/null || [[ "$?" == '52' ]]; do
    sleep 1
done
echo '`kpi` web service ready.'
