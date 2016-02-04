#!/bin/bash

echo "Clearing out any default configurations."
rm -rf /etc/nginx/conf.d/*

# Do environment variable substitutions.
cp /tmp/nginx_site_http.conf.tmpl /tmp/nginx_site_http.conf.tmp
for varname in KOBOCAT_PUBLIC_PORT KOBOFORM_PUBLIC_PORT KPI_PUBLIC_PORT ENKETO_EXPRESS_PUBLIC_PORT; do
    cat /tmp/nginx_site_http.conf.tmp | envsubst "'\${$varname}'" > /tmp/nginx_site_http.conf.swp
    mv /tmp/nginx_site_http.conf.swp /tmp/nginx_site_http.conf.tmp
done
cp /tmp/nginx_site_http.conf.tmp /etc/nginx/conf.d/kobo_site_http.conf

nginx &
nginx_pid=$!
trap "echo 'SIGTERM recieved. Killing Nginx.' && kill -SIGTERM ${nginx_pid}" SIGTERM
wait "${nginx_pid}"
exit $(($? - 128 - 15)) # http://unix.stackexchange.com/questions/10231/when-does-the-system-send-a-sigterm-to-a-process#comment13523_10231
