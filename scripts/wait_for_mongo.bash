#!/bin/bash
set -e

echo 'Waiting for container `mongo`.'
dockerize -timeout=40s -wait tcp://mongo:${MONGO_PORT}
echo 'Container `mongo` up.'
