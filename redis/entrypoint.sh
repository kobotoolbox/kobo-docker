#!/usr/bin/env bash

ORIGINAL_DIR="/tmp/redis"
REDIS_LOG_DIR="/var/log/redis"
REDIS_CONF_DIR="/etc/redis/"
REDIS_CONF_FILE="${REDIS_CONF_DIR}/redis.conf"
REDIS_DATA_DIR="/data/"

CONTAINER_IP=$(awk 'END{print $1}' /etc/hosts)

if [ ! -d "$REDIS_LOG_DIR" ]; then
    mkdir -p "$REDIS_LOG_DIR"
fi

if [ ! -d "$REDIS_DATA_DIR" ]; then
    mkdir -p "$REDIS_DATA_DIR"
fi


# Copy config file
cp "${REDIS_CONF_FILE}.tmpl" $REDIS_CONF_FILE

# Create redis-server configuration file
sed -i "s~\${CONTAINER_IP}~${CONTAINER_IP//\"/}~g" "$REDIS_CONF_FILE"

# Create redis-server configuration file
sed -i "s~\${REDIS_PASSWORD}~${REDIS_PASSWORD//\"/}~g" "$REDIS_CONF_FILE"

# Make logs directory writable
chown -R redis:redis "$REDIS_LOG_DIR"
chown redis:redis "$REDIS_CONF_FILE"
chown -R redis:redis "$REDIS_DATA_DIR"

if [ "${KOBO_REDIS_SERVER_ROLE}" == "main" ]; then
    BASH_PATH=$(which bash)
    export KOBO_DOCKER_SCRIPTS_DIR=/kobo-docker-scripts
    $BASH_PATH $KOBO_DOCKER_SCRIPTS_DIR/toggle-backup-activation.sh
fi

su redis -c "redis-server /etc/redis/redis.conf"
