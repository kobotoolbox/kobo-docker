#!/bin/bash
set -e

echo 'Waiting for container `mongo`.'
dockerize -timeout=40s -wait tcp://${KOBO_MONGO_HOST}:${KOBO_MONGO_PORT}
echo 'Container `mongo` up.'
