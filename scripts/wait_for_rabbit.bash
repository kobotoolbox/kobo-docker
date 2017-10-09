#!/bin/bash
set -e

echo 'Waiting for container `rabbit`.'
dockerize -timeout=40s -wait tcp://${KOBO_RABBIT_HOST}:${RABBIT_PORT}
echo 'Container `rabbit` up.'