# comented out - no use to have nginx listen on localhost :)
#listen      localhost:80;
# but then, why do we have this? theer must be a better way
listen      80;
charset     utf-8;
access_log  ${KOBO_NGINX_LOG_DIR}/kobocat.access.log;
error_log   ${KOBO_NGINX_LOG_DIR}/kobocat.error.log;

# max upload size
client_max_body_size 75M;

location /static {
   alias /srv/www/kobocat;
}

location / {
   uwsgi_pass kobocat;
   include /etc/nginx/uwsgi_params;
}
