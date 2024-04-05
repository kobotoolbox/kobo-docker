#!/bin/bash
set -e

KOBO_DOCKER_SCRIPTS_DIR='/kobo-docker-scripts'
INCLUDES_DIR='/etc/nginx/includes'

echo "Creating includes directory"
mkdir -p ${INCLUDES_DIR}

echo "Overwriting default nginx configuration"
cp ${KOBO_DOCKER_SCRIPTS_DIR}/nginx.conf /etc/nginx/nginx.conf

echo "Clearing out any default configurations"
rm -rf /etc/nginx/conf.d/*

export TEMPLATED_VAR_REFS="${TEMPLATED_VAR_REFS} \${NGINX_PUBLIC_PORT}"
export KOBOCAT_HEADER_FOR_DEV=''

if [[ "${WSGI}" != 'uWSGI' ]] ; then
    echo "Proxying directly (debug) to Django without uWSGI."

    # Create a `proxy_pass` configuration for this container.
    cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/proxy_pass.conf.tmpl \
        | envsubst '${KOBOFORM_PUBLIC_SUBDOMAIN} ${PUBLIC_DOMAIN_NAME} ${NGINX_PUBLIC_PORT}' \
        > ${INCLUDES_DIR}/proxy_pass.conf

    # Allow to open Kobocat in an iframe
    export KOBOCAT_HEADER_FOR_DEV='add_header X-Frame-Options ALLOWALL always;'
else
    echo "Proxying to Django through uWSGI."

    # Create a `uwsgi_pass` configuration for this container.
    cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/uwsgi_pass.conf.tmpl \
        | envsubst '${UWSGI_PASS_TIMEOUT}' \
        > ${INCLUDES_DIR}/proxy_pass.conf
fi

# Do environment variable substitutions and activate the resulting config. file.
cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/nginx_site_default.conf.tmpl | envsubst "${TEMPLATED_VAR_REFS} \${KOBOCAT_HEADER_FOR_DEV}" > /etc/nginx/conf.d/default.conf

# Copy includes files
cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/include.https_redirection.conf.tmpl | envsubst "${TEMPLATED_VAR_REFS}" > /etc/nginx/includes/https_redirection.conf
cp ${KOBO_DOCKER_SCRIPTS_DIR}/include.server_directive_common.conf /etc/nginx/includes/server_directive_common.conf
cp ${KOBO_DOCKER_SCRIPTS_DIR}/include.protected_directive.conf /etc/nginx/includes/protected_directive.conf
