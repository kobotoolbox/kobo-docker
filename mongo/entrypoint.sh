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

# TODO: remove once MongoDB has fixed SERVER-121912.
# MongoDB 8 is incompatible with Linux Kernel 6.19 Through 7.0.13.
# See https://www.mongodb.com/docs/v8.0/release-notes/8.0
#  - kernels 6.19 to 7.0.13 are broken;
#  - kernels 7.0.14 and newer are fixed, but `mongod` keeps refusing to start
#    on them until it carries SERVER-125742.
kernel=$(uname -r | cut -d- -f1)

kernel_at_least() {
    [ "$(printf '%s\n%s\n' "$kernel" "$1" | sort -V | head -1)" = "$1" ]
}

if kernel_at_least 6.19; then
    if ! kernel_at_least 7.0.14 || ! mongod --version > /dev/null 2>&1; then
        echo "Kernel $kernel: applying MongoDB rseq workaround"
        export GLIBC_TUNABLES=glibc.pthread.rseq=1
    fi
fi

echo "Launching official entrypoint..."
# `exec` here is important to pass signals to the database server process;
# without `exec`, the server will be terminated abruptly with SIGKILL (see #276)
exec docker-entrypoint.sh mongod
