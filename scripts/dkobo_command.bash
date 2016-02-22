#!/bin/bash
set -e

# Ensure that the system starts with a user with credentials kobo:kobo
cp /srv/src/koboform/docker/create_demo_user.sh /etc/my_init.d/20_create_demo_user.bash

/sbin/my_init &
my_init_pid=$(pgrep my_init)
trap "echo 'SIGTERM recieved. Killing my_init.' && kill -SIGTERM ${my_init_pid}" SIGTERM
wait "${my_init_pid}"
exit $(( ($? - 128) - 15 )) # http://unix.stackexchange.com/questions/10231/when-does-the-system-send-a-sigterm-to-a-process#comment13523_10231
