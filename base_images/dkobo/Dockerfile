FROM teodorescuserban/kobo-base-dkobo:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

COPY run_wsgi /etc/service/wsgi/run
COPY *.sh koboform.ini /srv/src/

RUN /etc/my_init.d/00_regen_ssh_host_keys.sh && \
    chmod +x /etc/service/wsgi/run && \
    chown -R wsgi /srv/src/koboform

USER wsgi

RUN cd /srv/src/koboform && \
    bower install --config.interactive=false && \
    npm --no-color install --save-dev

USER root

VOLUME ["/srv/src/koboform"]

EXPOSE 8000

CMD ["/sbin/my_init"]
