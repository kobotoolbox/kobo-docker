#!/usr/bin/env bash
# set -e

export KOBO_DOCKER_SCRIPTS_DIR=/kobo-docker-scripts

# Send backup installation process in background to avoid blocking MongoDB startup
bash $KOBO_DOCKER_SCRIPTS_DIR/toggle-backup-activation.sh &

echo "Copying init scripts ..."
cp $KOBO_DOCKER_SCRIPTS_DIR/init_* /docker-entrypoint-initdb.d/

bash $KOBO_DOCKER_SCRIPTS_DIR/upsert_users.sh

# Send post startup tasks in background to avoid blocking MongoDB startup
bash $KOBO_DOCKER_SCRIPTS_DIR/post_startup.sh &

echo "Launching official entrypoint..."
# `exec` here is important to pass signals to the database server process;
# without `exec`, the server will be terminated abruptly with SIGKILL (see #276)
exec docker-entrypoint.sh mongod
