#!/bin/bash
set -e

KOBO_DOCKER_SCRIPTS_DIR='/kobo-docker-scripts'
INCLUDES_DIR='/etc/nginx/includes'

TEMPLATED_VAR_REFS="\${ETA} \${DATE_STR} \${EMAIL} \${DATE_ISO} \${PUBLIC_REQUEST_SCHEME} \${INTERNAL_DOMAIN_NAME} \${PUBLIC_DOMAIN_NAME} \${KOBOFORM_PUBLIC_SUBDOMAIN} \${KOBOCAT_PUBLIC_SUBDOMAIN} \${ENKETO_EXPRESS_PUBLIC_SUBDOMAIN}"

echo "Overwrite default nginx configuration"
cp ${KOBO_DOCKER_SCRIPTS_DIR}/nginx.conf /etc/nginx/nginx.conf

echo "Clearing out any default configurations"
rm -rf /etc/nginx/conf.d/*

echo "Creating includes"
mkdir -p ${INCLUDES_DIR}
cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/include.https_redirection.conf.tmpl | envsubst "${TEMPLATED_VAR_REFS}" > /etc/nginx/includes/https_redirection.conf

# Do environment variable substitutions and activate the resulting config. file.
echo "Creating default config"
cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/maintenance_default.conf.tmpl | envsubst "${TEMPLATED_VAR_REFS}" > /etc/nginx/conf.d/default.conf

# Create index.html
echo "Creating index.html"
cat /www/index.html.tmpl | envsubst "${TEMPLATED_VAR_REFS}" > /www/index.html
