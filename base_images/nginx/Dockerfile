FROM kobotoolbox/base-nginx:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

COPY uwsgi_params /etc/nginx/u_p
RUN mkdir -p /srv/www/kobocat && \
    mv /srv/* /etc/nginx/ && \
    mv /etc/nginx/uwsgi_params /etc/nginx/uwsgi_params.bak && \
    mv /etc/nginx/u_p /etc/nginx/uwsgi_params && \
    rm -rf /etc/nginx/sites-enabled/*

EXPOSE 80 443

VOLUME ["/srv/www", "/var/log/nginx", "/etc/nginx", "/tmp"]

RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

CMD ["/sbin/my_init"]
