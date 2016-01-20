FROM teodorescuserban/kobo-base-nginx:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

COPY nginx_templates/* run_nginx /srv/
COPY uwsgi_params /etc/nginx/u_p
RUN mv /srv/run_nginx /etc/service/nginx/run && \
    chmod +x /etc/service/nginx/run && \
    mkdir -p /srv/www/kobocat /srv/www/dkobo && \
    mv /srv/* /etc/nginx/ && \
    mv /etc/nginx/uwsgi_params /etc/nginx/uwsgi_params.bak && \
    mv /etc/nginx/u_p /etc/nginx/uwsgi_params && \
    rm -rf /etc/nginx/sites-enabled/* && \
    ln -s /etc/nginx/kobo.conf /etc/nginx/sites-enabled/kobo && \
    rm -rf /etc/nginx/kobo.conf

EXPOSE 80 443

VOLUME ["/srv/www", "/var/log/nginx", "/etc/nginx", "/tmp"]

RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

CMD ["/sbin/my_init"]
