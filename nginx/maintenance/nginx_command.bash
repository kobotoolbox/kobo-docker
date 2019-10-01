#!/bin/bash
set -e

ORIGINAL_DIR='/tmp/kobo_nginx'

TEMPLATED_VAR_REFS="\${ETA} \${DATE_STR} \${EMAIL} \${DATE_ISO} \${PUBLIC_REQUEST_SCHEME} \${INTERNAL_DOMAIN_NAME} \${PUBLIC_DOMAIN_NAME} \${KOBOFORM_PUBLIC_SUBDOMAIN} \${KOBOCAT_PUBLIC_SUBDOMAIN} \${ENKETO_EXPRESS_PUBLIC_SUBDOMAIN}"

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

echo "Preparing www root..."
rm -rf /www
mkdir /www
cp -R ${ORIGINAL_DIR}/maintenance/www/*.* /www
rm -rf /www/index.html.tmpl

# Create index.html
echo "Creating index.html..."
cat ${ORIGINAL_DIR}/maintenance/www/index.html.tmpl | envsubst "${TEMPLATED_VAR_REFS}" > /www/index.html

# Start Nginx.
echo "Starting nginx..."
exec nginx
