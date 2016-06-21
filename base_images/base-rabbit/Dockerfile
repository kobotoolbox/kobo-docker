FROM kobotoolbox/base:latest

RUN echo 'deb http://www.rabbitmq.com/debian/ testing main'> /etc/apt/sources.list.d/rabbitmq.list && \
    curl -s https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | apt-key add - && \
    apt-get -qq update && \
    apt-get -qq -y install \
        rabbitmq-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /etc/service/rabbit && \
    touch /etc/service/rabbit/run && \
    mkdir -p /etc/service/rabbit-configure && \
    touch /etc/service/rabbit-configure/run
