#!/bin/bash
set -e

echo 'Waiting for container `rabbit`.'
dockerize -timeout=40s -wait tcp://rabbit:${RABBIT_PORT}
echo 'Container `rabbit` up.'

#echo 'Waiting for container `rabbit`.'
#sleep 40
#IS_OPENED=$((echo > /dev/tcp/rabbit/${RABBIT_PORT//\"/}) >/dev/null 2>&1 && echo "1" || echo "0")
#
#if [ "$IS_OPENED" == "1" ]; then
#    echo 'Container `rabbit` up.'
#else
#    echo 'Container `rabbit` down.'
#fi
