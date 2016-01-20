FROM teodorescuserban/kobo-base-kobocat:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

RUN mkdir -p /etc/service/celery

COPY run_wsgi /etc/service/wsgi/run
COPY run_celery /etc/service/celery/run
COPY *.sh kobocat.ini /srv/src/

RUN /etc/my_init.d/00_regen_ssh_host_keys.sh && \
    chmod +x /etc/service/wsgi/run && \
    chmod +x /etc/service/celery/run && \
    echo "db:*:*:kobo:kobo" > /root/.pgpass && \
    chmod 600 /root/.pgpass

VOLUME ["/srv/src/kobocat", "/srv/src/kobocat/onadata/media", "/srv/src/kobocat-template", "/tmp"]

EXPOSE 8000

CMD ["/sbin/my_init"]
