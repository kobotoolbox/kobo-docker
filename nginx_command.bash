#!/bin/bash

echo "Clearing out any default configurations."
rm -rf /etc/nginx/conf.d/*

# Do environment variable substitutions.
cp /tmp/nginx_site_https.conf.tmpl /tmp/nginx_site_https.conf.tmp
for varname in PUBLIC_DOMAIN_NAME KOBOFORM_PUBLIC_SUBDOMAIN KOBOCAT_PUBLIC_SUBDOMAIN ENKETO_EXPRESS_PUBLIC_SUBDOMAIN; do
    cat /tmp/nginx_site_https.conf.tmp | envsubst "'\${$varname}'" > /tmp/nginx_site_https.conf.swp
    mv /tmp/nginx_site_https.conf.swp /tmp/nginx_site_https.conf.tmp
done
cp /tmp/nginx_site_https.conf.tmp /etc/nginx/conf.d/kobo_site_https.conf

nginx &
nginx_pid=$!
trap "echo 'SIGTERM recieved. Killing Nginx.' && kill -SIGTERM ${nginx_pid}" SIGTERM
wait "${nginx_pid}"
exit $(($? - 128 - 15)) # http://unix.stackexchange.com/questions/10231/when-does-the-system-send-a-sigterm-to-a-process#comment13523_10231
