#!/bin/bash
set -e

ORIGINAL_DIR='/tmp/kobo_nginx'

echo "Overwrite default nginx configuration..."
cp /tmp/kobo_nginx/nginx.conf /etc/nginx/nginx.conf

echo "Clearing out any default configurations..."
rm -rf /etc/nginx/conf.d/*

# Copy extra logs config.
echo "Copying custom logs format..."
cp ${ORIGINAL_DIR}/logs_with_host.conf /etc/nginx/conf.d/_logs_with_host.conf

# Copy includes files
echo "Creating includes..."
cat ${ORIGINAL_DIR}/include.https_redirection.conf.tmpl | envsubst "${TEMPLATED_VAR_REFS}" > /etc/nginx/include.https_redirection.conf

# Do environment variable substitutions and activate the resulting config. file.
echo "Creating default config..."
cat ${ORIGINAL_DIR}/maintenance/nginx_site_default.conf.tmpl | envsubst "${TEMPLATED_VAR_REFS}" > /etc/nginx/conf.d/default.conf

# Create symlink
#if [ ! -f /etc/nginx/sites-enabled/default ]; then
#    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
#fi

# Start Nginx.
echo "Starting nginx..."
exec nginx
