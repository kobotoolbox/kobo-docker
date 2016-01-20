FROM kobotoolbox/base:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

COPY run_nginx /

RUN apt-get -qq update && \
    apt-get install -qq -y \
        nginx-extras && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    echo "daemon off;" >> /etc/nginx/nginx.conf && \
    mkdir -p /etc/service/nginx && \
    mv /run_nginx /etc/service/nginx/run && \
    chmod u+x /etc/service/nginx/run

#    nginx-full
