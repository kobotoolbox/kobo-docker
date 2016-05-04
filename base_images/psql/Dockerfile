FROM kobotoolbox/base-psql:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

COPY pg_hba.conf postgresql.conf /etc/postgresql/9.4/main/

RUN mkdir -p /srv/backups/ /srv/db && \
    /etc/my_init.d/00_regen_ssh_host_keys.sh && \
    chown postgres:postgres /srv/db && \
    sudo -u postgres /usr/lib/postgresql/9.4/bin/initdb -D /srv/db -E utf-8 --locale=en_US.UTF-8

COPY run_psql /etc/service/psql/run
COPY ./init_postgres.bash /etc/my_init.d/init_postgres.bash

VOLUME ["/srv/db", "/srv/backups/"]
EXPOSE 5432

CMD ["/sbin/my_init"]
