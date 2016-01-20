listen      443 ssl;
charset     utf-8;
access_log  ${KOBO_NGINX_LOG_DIR}/kobocat.access.log;
error_log   ${KOBO_NGINX_LOG_DIR}/kobocat.error.log;

# max upload size
client_max_body_size 75M;

ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
# ssl_ciphers prevents Forward Secrecy; requires >ie6/winxp
# DHE-RSA-AES128-SHA provides Android 2.3 compatibility. No need
# to add it again to the kf.kobotoolbox.org configuration;
# old Android doesn't support SNI and would never see it there.
ssl_ciphers 'AES256+EECDH:AES256+EDH:DHE-RSA-AES128-SHA';

include ${KOBO_NGINX_BASE_DIR}/kc_include.conf;
