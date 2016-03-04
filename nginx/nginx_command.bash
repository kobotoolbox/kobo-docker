#!/bin/bash
set -e

ORIGINAL_DIR='/tmp/kobo_nginx'
TEMPLATES_ENABLED_DIR='/tmp/nginx_templates_activated'

mkdir -p ${TEMPLATES_ENABLED_DIR}

echo "Clearing out any default configurations."
rm -rf /etc/nginx/conf.d/*

templated_var_refs="${TEMPLATED_VAR_REFS}"
declare -A container_ports
container_ports=( ['kpi']='8000' ['kobocat']='8000' )
for container_name in "${!container_ports[@]}"; do

    debug_varname="NGINX_DEBUG_${container_name}"     # E.g. `NGINX_DEBUG_kpi`.
    if [[ "${!debug_varname}" == 'True' ]] ; then
        echo "Debug proxying directly to \`${container_name}\` without uWSGI."

        # Create a `proxy_pass` configuration for this container.
        cat ${ORIGINAL_DIR}/proxy_pass.conf.tmpl \
            | container_name="${container_name}" envsubst '${container_name}' \
            | container_port="${container_ports[${container_name}]}" envsubst '${container_port}' \
            > ${TEMPLATES_ENABLED_DIR}/${container_name}_proxy_pass.conf

        # Prepare to include the generated `proxy_pass` config. and no `uwsgi_pass` config.
        export ${container_name}_include_proxy_pass="include ${TEMPLATES_ENABLED_DIR}/${container_name}_proxy_pass.conf;"
        export ${container_name}_include_uwsgi_pass=''
    else
        echo "Proxying to \`${container_name}\` through uWSGI."

        # Create a `uwsgi_pass` configuration for this container.
        cat ${ORIGINAL_DIR}/uwsgi_pass.conf.tmpl \
            | container_name="${container_name}" envsubst '${container_name}' \
            | container_port="${container_ports[$container_name]}" envsubst '${container_port}' \
            > ${TEMPLATES_ENABLED_DIR}/${container_name}_uwsgi_pass.conf
 
        # Prepare to include the generated `uwsgi_pass` config. and no `proxy_pass` config.
        export ${container_name}_include_proxy_pass=''
        export ${container_name}_include_uwsgi_pass="include ${TEMPLATES_ENABLED_DIR}/${container_name}_uwsgi_pass.conf;"
    fi

    # Register the include directive variables (e.g. `kpi_include_proxy_pass` and `kpi_include_uwsgi_pass`)
    #   for template substitution.
    templated_var_refs+=" \${${container_name}_include_proxy_pass} \${${container_name}_include_uwsgi_pass}"
done

# Do environment variable substitutions and activate the resulting config. file.
cat ${ORIGINAL_DIR}/${NGINX_CONFIG_FILE_NAME}.tmpl | envsubst "${templated_var_refs}" > /etc/nginx/conf.d/${NGINX_CONFIG_FILE_NAME}

# Start Nginx.
exec nginx
