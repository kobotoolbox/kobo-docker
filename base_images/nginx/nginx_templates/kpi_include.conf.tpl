location /forms/static {
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
}

error_page 418 = /static/html/Offline.html;

location /forms/ {
    if (%maintenance = "yes") {
        return 418;
    }
    uwsgi_read_timeout 130;
    uwsgi_send_timeout 130;
    uwsgi_pass kpi;
    include /etc/nginx/uwsgi_params;
}
