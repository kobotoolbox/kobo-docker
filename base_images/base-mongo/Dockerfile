FROM kobotoolbox/base:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

COPY mongodb.list /etc/apt/sources.list.d/

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
    apt-get -qq update && \
    apt-get -qq -y install \
        mongodb-org-server \
        mongodb-org-shell \
        mongodb-org-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /etc/service/mongo && \
    touch /etc/service/mongo/run
