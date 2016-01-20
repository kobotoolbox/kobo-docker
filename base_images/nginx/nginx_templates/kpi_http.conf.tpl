# no `listen`, etc. for now, because that's done by the dkobo configuration,
# which is included before this
#listen      80;
#access_log  ${KOBO_NGINX_LOG_DIR}/kpi.access.log;
#error_log   ${KOBO_NGINX_LOG_DIR}/kpi.error.log;

include ${KOBO_NGINX_BASE_DIR}/kpi_include.conf;

# Comment out the `include` above and uncomment the `return` below to redirect
# HTTP traffic to HTTPS. It's okay to unconditionally redirect KPI to HTTPS
# since ODK Collect never touches it
#return 301 https://%server_name%request_uri;
