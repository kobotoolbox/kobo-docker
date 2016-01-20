listen      80;
access_log  ${KOBO_NGINX_LOG_DIR}/koboform.access.log;
error_log   ${KOBO_NGINX_LOG_DIR}/koboform.error.log;

include ${KOBO_NGINX_BASE_DIR}/kf_include.conf;

# Comment out the `include` above and uncomment the `return` below to redirect
# HTTP traffic to HTTPS. It's okay to unconditionally redirect KF to HTTPS
# since ODK Collect never touches it
#return 301 https://%server_name%request_uri;
