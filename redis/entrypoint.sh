#!/usr/bin/env bash

ORIGINAL_DIR="/tmp/redis"
REDIS_LOG_DIR="/var/log/redis"
REDIS_CONF_DIR="/etc/redis"
REDIS_CONF_FILE="${REDIS_CONF_DIR}/redis.conf"
REDIS_DATA_DIR="/data/"

export CONTAINER_IP=$(awk 'END{print $1}' /etc/hosts)
export REDIS_PASSWORD=$(echo $REDIS_PASSWORD | sed 's/"/\\"/g')

if [[ ! -d "$REDIS_LOG_DIR" ]]; then
    mkdir -p "$REDIS_LOG_DIR"
fi

if [[ ! -d "$REDIS_DATA_DIR" ]]; then
    mkdir -p "$REDIS_DATA_DIR"
fi

awk '{ gsub(/\${CONTAINER_IP}/,ENVIRON["CONTAINER_IP"])
       gsub(/\${REDIS_PASSWORD}/,ENVIRON["REDIS_PASSWORD"])
       gsub(/\${REDIS_CACHE_MAX_MEMORY}/,ENVIRON["REDIS_CACHE_MAX_MEMORY"])
       print }' "$REDIS_CONF_FILE.tmpl" > "$REDIS_CONF_FILE"

if [[ -z "$REDIS_PASSWORD" ]]; then
    sed -i 's/requirepass ""//g' "$REDIS_CONF_FILE"
fi

if [[ -z "$REDIS_CACHE_MAX_MEMORY" ]]; then
    sed -i 's/maxmemory mb//g' "$REDIS_CONF_FILE"
    sed -i 's/maxmemory-policy volatile-ttl//g' "$REDIS_CONF_FILE"
fi

# Make logs directory writable
chown -R redis:redis "$REDIS_LOG_DIR"
chown redis:redis "$REDIS_CONF_FILE"
chown -R redis:redis "$REDIS_DATA_DIR"

if [[ "$KOBO_REDIS_SERVER_ROLE" == "main" ]]; then
    # Send backup installation process in background to avoid blocking redis startup
    export KOBO_DOCKER_SCRIPTS_DIR=/kobo-docker-scripts
    /bin/bash "$KOBO_DOCKER_SCRIPTS_DIR/toggle-backup-activation.sh" &
fi

# `exec` here is important to pass signals to the standard entrypoint script;
# without it, the server will be terminated abruptly with SIGKILL (see #276)
# For reference, the standard entrypoint script can be found at:
# https://github.com/redis/docker-library-redis/blob/release/7.2/debian/docker-entrypoint.sh
exec docker-entrypoint.sh /etc/redis/redis.conf
