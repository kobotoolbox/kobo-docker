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

templated_var_refs="${TEMPLATED_VAR_REFS}"
declare -A container_ports
container_ports=( ['kpi']='8000' ['kobocat']='8001' )

if [ "${NGINX_PUBLIC_PORT:-80}" != "80" ]; then
    export container_public_port=":${NGINX_PUBLIC_PORT}"
else
    export container_public_port=""
fi
templated_var_refs+=" \${container_public_port}"

for container_name in "${!container_ports[@]}"; do
    export container_name
    export container_port="${container_ports[${container_name}]}"

    # Set up proxying to apps.
    web_server_varname="${container_name^^}_WEB_SERVER"     # E.g. `kpi_WEB_SERVER`.
    web_server="${!web_server_varname}"
    if [[ "${web_server^^}" != 'UWSGI' ]] ; then
        echo "Proxying directly (debug) to \`${container_name}\` without uWSGI."

        if [ "${container_name}" == "kpi" ]; then
            export container_x_forwarded_host="${KOBOFORM_PUBLIC_SUBDOMAIN}.${PUBLIC_DOMAIN_NAME}"
        else
            export container_x_forwarded_host="${KOBOCAT_PUBLIC_SUBDOMAIN}.${PUBLIC_DOMAIN_NAME}"
        fi

        # Create a `proxy_pass` configuration for this container.
        cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/proxy_pass.conf.tmpl \
            | envsubst '${container_name} ${container_port} ${container_public_port} ${container_x_forwarded_host}' \
            > ${INCLUDES_DIR}/${container_name}_proxy_pass.conf

        # Prepare to include the generated `proxy_pass` config. and no `uwsgi_pass` config.
        include_proxy_pass="include ${INCLUDES_DIR}/${container_name}_proxy_pass.conf;"
        include_uwsgi_pass=''
    else
        echo "Proxying to \`${container_name}\` through uWSGI."

        # Create a `uwsgi_pass` configuration for this container.
        cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/uwsgi_pass.conf.tmpl \
            | envsubst '${container_name} ${container_port} ${UWSGI_PASS_TIMEOUT}' \
            > ${INCLUDES_DIR}/${container_name}_uwsgi_pass.conf
 
        # Prepare to include the generated `uwsgi_pass` config. and no `proxy_pass` config.
        include_proxy_pass=''
        include_uwsgi_pass="include ${INCLUDES_DIR}/${container_name}_uwsgi_pass.conf;"
    fi
    include_proxy_pass_varname="${container_name}_include_proxy_pass"
    export ${include_proxy_pass_varname}="${include_proxy_pass}"
    include_uwsgi_pass_varname="${container_name}_include_uwsgi_pass"
    export ${include_uwsgi_pass_varname}="${include_uwsgi_pass}"

    # Register the include directive variables (e.g. `kpi_include_proxy_pass` and `kpi_include_uwsgi_pass`)
    # for template substitution.
    templated_var_refs+=" \${${include_proxy_pass_varname}} \${${include_uwsgi_pass_varname}}"

done

# Do environment variable substitutions and activate the resulting config. file.
cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/nginx_site_default.conf.tmpl | envsubst "${templated_var_refs}" > /etc/nginx/conf.d/default.conf

# Copy includes files
cat ${KOBO_DOCKER_SCRIPTS_DIR}/templates/include.https_redirection.conf.tmpl | envsubst "${templated_var_refs}" > /etc/nginx/includes/https_redirection.conf
cp ${KOBO_DOCKER_SCRIPTS_DIR}/include.server_directive_common.conf /etc/nginx/includes/server_directive_common.conf
cp ${KOBO_DOCKER_SCRIPTS_DIR}/include.protected_directive.conf /etc/nginx/includes/protected_directive.conf
