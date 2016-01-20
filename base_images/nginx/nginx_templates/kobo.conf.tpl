
# enable maintenance
map %host %maintenance {
    # default "yes";
    default "no";
}


# The ORDER of the servers is important!
# Dumb, non-SNI clients will receive the certificate
# for the first HTTPS server listed.

upstream kobocat {
    server ${KOBOCAT_SERVER_ADDR}:${KOBOCAT_SERVER_PORT};
}

server {
    include ${KOBO_NGINX_BASE_DIR}/kc_http.conf;
    server_name ${KOBO_PREFIX}kc.${KOBO_DOMAIN};
}

# commented out - it overlaps on the above one.
#server {
#    include ${KOBO_NGINX_BASE_DIR}/kc_loopback.conf;
#    # Be sure that hostname specified for server_name resolves to the same
#    # address as localhost. Set it in /etc/hosts if necessary.
#    server_name ${KOBO_PREFIX}kc.${KOBO_DOMAIN};
#}

server {
    include ${KOBO_NGINX_BASE_DIR}/kc_https.conf;
    server_name ${KOBO_PREFIX}kc.${KOBO_DOMAIN};
    ssl_certificate ${KOBO_NGINX_BASE_DIR}/ssl.crt;
    ssl_certificate_key ${KOBO_NGINX_BASE_DIR}/ssl.key;
}

upstream koboform {
    server ${KOBOFORM_SERVER_ADDR}:${KOBOFORM_SERVER_PORT};
}

upstream kpi {
    server ${KPI_SERVER_ADDR}:${KPI_SERVER_PORT};
}

server {
    include ${KOBO_NGINX_BASE_DIR}/kf_http.conf;
    include ${KOBO_NGINX_BASE_DIR}/kpi_http.conf;
    server_name ${KOBO_PREFIX}kobo.${KOBO_DOMAIN};
}

server {
    include ${KOBO_NGINX_BASE_DIR}/kf_https.conf;
    include ${KOBO_NGINX_BASE_DIR}/kpi_https.conf;
    server_name ${KOBO_PREFIX}kobo.${KOBO_DOMAIN};
    ssl_certificate ${KOBO_NGINX_BASE_DIR}/ssl.crt;
    ssl_certificate_key ${KOBO_NGINX_BASE_DIR}/ssl.key;
}
