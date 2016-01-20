FROM teodorescuserban/kobo-base:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

#ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update && \
    apt-get -qq -y install \
        postgresql-9.3 \
        postgresql-client-9.3 \
        postgresql-contrib-9.3 \
        postgis \
        postgresql-9.3-postgis-2.1 \
        libpq-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /etc/service/psql && \
    touch /etc/service/psql/run
