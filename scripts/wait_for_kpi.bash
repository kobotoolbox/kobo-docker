#!/bin/bash
set -e

echo 'Waiting for container `kpi`.'
wait-for-it -t 300 -h kpi -p $KPI_PORT
echo 'Container `kpi` up.'

echo 'Waiting for `kpi` web service.'
until curl kpi:${KPI_PORT} &> /dev/null || [[ "$?" == '52' ]]; do
    sleep 1
done
echo '`kpi` web service ready.'
