#!/bin/bash
set -e

echo 'Waiting for container `mongo`.'
wait-for-it -t 40 -h $KOBO_MONGO_HOST -p $KOBO_MONGO_PORT
echo 'Container `mongo` up.'
