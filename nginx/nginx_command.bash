#!/bin/bash
set -e

ORIGINAL_DIR='/tmp/kobo_nginx'
TEMPLATES_ENABLED_DIR='/tmp/nginx_templates_activated'
KOBOCAT_PRODUCTION_LOCATION_STATIC='location /static {
        alias /srv/www/kobocat;
    }'
KPI_PRODUCTION_LOCATION_STATIC='location /static {
        alias /srv/www/kpi;

        # gzip configs from here
        # http://stackoverflow.com/a/12644530/3088435
        gzip on;
        gzip_disable "msie6";
        gzip_comp_level 6;
        gzip_min_length 1100;
        gzip_buffers 16 8k;
        gzip_proxied any;
        gzip_types
            text/plain
            text/css
            text/js
            text/xml
            text/javascript
            application/javascript
            application/x-javascript
            application/json
            application/xml
            application/xml+rss;
    }'

mkdir -p ${TEMPLATES_ENABLED_DIR}

echo "Clearing out any default configurations."
rm -rf /etc/nginx/conf.d/*

templated_var_refs="${TEMPLATED_VAR_REFS}"
declare -A container_ports
container_ports=( ['kpi']='8000' ['kobocat']='8000' )
for container_name in "${!container_ports[@]}"; do
    export container_name
    export container_port="${container_ports[${container_name}]}"

    # Set up proxying to apps.
    web_server_varname="${container_name^^}_WEB_SERVER"     # E.g. `kpi_WEB_SERVER`.
    web_server="${!web_server_varname}"
    if [[ "${web_server^^}" != 'UWSGI' ]] ; then
        echo "Proxying directly (debug) to \`${container_name}\` without uWSGI."

        # Create a `proxy_pass` configuration for this container.
        cat ${ORIGINAL_DIR}/proxy_pass.conf.tmpl \
            | envsubst '${container_name} ${container_port}' \
            > ${TEMPLATES_ENABLED_DIR}/${container_name}_proxy_pass.conf

        # Prepare to include the generated `proxy_pass` config. and no `uwsgi_pass` config.
        include_proxy_pass="include ${TEMPLATES_ENABLED_DIR}/${container_name}_proxy_pass.conf;"
        include_uwsgi_pass=''
    else
        echo "Proxying to \`${container_name}\` through uWSGI."

        # Create a `uwsgi_pass` configuration for this container.
        cat ${ORIGINAL_DIR}/uwsgi_pass.conf.tmpl \
            | envsubst '${container_name} ${container_port}' \
            > ${TEMPLATES_ENABLED_DIR}/${container_name}_uwsgi_pass.conf
 
        # Prepare to include the generated `uwsgi_pass` config. and no `proxy_pass` config.
        include_proxy_pass=''
        include_uwsgi_pass="include ${TEMPLATES_ENABLED_DIR}/${container_name}_uwsgi_pass.conf;"
    fi
    include_proxy_pass_varname="${container_name}_include_proxy_pass"
    export ${include_proxy_pass_varname}="${include_proxy_pass}"
    include_uwsgi_pass_varname="${container_name}_include_uwsgi_pass"
    export ${include_uwsgi_pass_varname}="${include_uwsgi_pass}"

    # Register the include directive variables (e.g. `kpi_include_proxy_pass` and `kpi_include_uwsgi_pass`)
    #   for template substitution.
    templated_var_refs+=" \${${include_proxy_pass_varname}} \${${include_uwsgi_pass_varname}}"

    # Set up serving of static files.
    static_files_server_varname="${container_name^^}_STATIC_FILES_SERVER"
    static_files_server="${!static_files_server_varname}"
    django_debug_varname="${container_name^^}_DJANGO_DEBUG"
    django_debug="${!django_debug_varname}"
    if [[ "${static_files_server^^}" == "NGINX" ]]; then
        echo "Serving static files for container ${container_name} from Nginx."
        production_location_static_varname="${container_name^^}_PRODUCTION_LOCATION_STATIC"
        location_static="${!production_location_static_varname}"
    elif [[ "${static_files_server^^}" == "DJANGO" && "${django_debug^^}" == "TRUE" ]]; then
        echo "Serving static files for container ${container_name} from Django."
        location_static=''
    elif [[ "${static_files_server^^}" == "DJANGO" && "${django_debug^^}" != "TRUE" ]]; then
        echo "Cannot serve static files from Django for container \`${container_name}\` unless \`${django_debug_varname}\` set to \"True\" in \`/envfiles/${container_name}.txt\`."
        exit 1
    fi
    location_static_varname="${container_name}_location_static"
    export ${location_static_varname}="${location_static}"
    templated_var_refs+=" \${$location_static_varname}}"

done

# Do environment variable substitutions and activate the resulting config. file.
cat ${ORIGINAL_DIR}/${NGINX_CONFIG_FILE_NAME}.tmpl | envsubst "${templated_var_refs}" > /etc/nginx/conf.d/${NGINX_CONFIG_FILE_NAME}

# Start Nginx.
exec nginx
