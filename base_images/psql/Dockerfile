FROM kobotoolbox/base-psql:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

COPY pg_hba.conf postgresql.conf /etc/postgresql/9.4/main/
COPY run_psql /etc/service/psql/run
COPY ./init_postgres.bash /etc/my_init.d/init_postgres.bash

#COPY server.crt server.key /srv/

RUN mkdir -p /srv/backup /srv/db && \
    /etc/my_init.d/00_regen_ssh_host_keys.sh && \
    chmod +x /etc/service/psql/run && \
    chown postgres:postgres /srv/db && \
    sudo -u postgres /usr/lib/postgresql/9.4/bin/initdb -D /srv/db -E utf-8 --locale=en_US.UTF-8

#    chown postgres:postgres /srv/server.* && \
#    chmod 640 /srv/server.key && \

VOLUME ["/srv/db"]
EXPOSE 5432

CMD ["/sbin/my_init"]
