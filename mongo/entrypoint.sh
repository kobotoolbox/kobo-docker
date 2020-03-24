#!/usr/bin/env bash
# set -e

BASH_PATH=$(which bash)
export KOBO_DOCKER_SCRIPTS_DIR=/kobo-docker-scripts

$BASH_PATH $KOBO_DOCKER_SCRIPTS_DIR/toggle-backup-activation.sh

echo "Copying init scripts ..."
cp $KOBO_DOCKER_SCRIPTS_DIR/init_* /docker-entrypoint-initdb.d/

$BASH_PATH $KOBO_DOCKER_SCRIPTS_DIR/upsert_users.sh

echo "Launching official entrypoint..."
$BASH_PATH /entrypoint.sh mongod
