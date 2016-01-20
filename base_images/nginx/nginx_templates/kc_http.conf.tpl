listen      80;
charset     utf-8;
access_log  ${KOBO_NGINX_LOG_DIR}/kobocat.access.log;
error_log   ${KOBO_NGINX_LOG_DIR}/kobocat.error.log;

# max upload size
client_max_body_size 75M;

# Serve locations containing 'submission' or 'formList' via HTTP without
# further ado, since ODK Collect makes requests containing those terms and
# does not support any kind of redirection.
location ~ (submission|formList) {
   uwsgi_read_timeout 130;
   uwsgi_send_timeout 130;
   uwsgi_pass kobocat;
   include /etc/nginx/uwsgi_params;
}

include ${KOBO_NGINX_BASE_DIR}/kc_include.conf;

# Comment out the `include` above and uncomment the `location` block below to
# redirect all non-ODK-Collect requests to HTTPS
#location / {
#   return 301 https://%server_name%request_uri;
#}
