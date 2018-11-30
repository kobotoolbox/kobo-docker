#!/bin/bash
set -e

echo 'Waiting for container `kpi`.'
dockerize -timeout=60s -wait tcp://kpi:${KPI_PORT}
echo 'Container `kpi` up.'

echo 'Waiting for `kpi` web service.'
until curl kpi:${KPI_PORT} &> /dev/null || [[ "$?" == '52' ]]; do
    sleep 1
done
echo '`kpi` web service ready.'
