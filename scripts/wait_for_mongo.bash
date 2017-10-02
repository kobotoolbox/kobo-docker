#!/bin/bash
set -e

#echo 'Waiting for container `mongo`.'
#dockerize -timeout=40s -wait ${MONGO_PORT}
#echo 'Container `mongo` up.'

echo 'Waiting for container `mongo`.'
sleep 40
IS_OPENED=$((echo > /dev/tcp/mongo/${MONGO_PORT//\"/}) >/dev/null 2>&1 && echo "1" || echo "0")

if [ "$IS_OPENED" == "1" ]; then
    echo 'Container `mongo` up.'
else
    echo 'Container `mongo` down.'
fi