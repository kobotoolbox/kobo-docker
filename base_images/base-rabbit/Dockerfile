FROM teodorescuserban/kobo-base:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

RUN apt-get -qq update && \
    apt-get -qq -y install \
        rabbitmq-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /etc/service/rabbit && \
    touch /etc/service/rabbit/run && \
    mkdir -p /etc/service/rabbit-configure && \
    touch /etc/service/rabbit-configure/run
