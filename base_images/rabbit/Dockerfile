FROM kobotoolbox/base-rabbit:latest

COPY run_rabbit /etc/service/rabbit/run
COPY run_rabbit-configure /etc/service/rabbit-configure/run
RUN chmod +x /etc/service/rabbit/run && \
    chmod +x /etc/service/rabbit-configure/run && \
    /etc/my_init.d/00_regen_ssh_host_keys.sh

# do we need this?
#    rabbitmq-plugins enable rabbitmq_management && \


# only RabbitMQ
EXPOSE 5672

# for RabbitMQ and RabbitMQ Admin
#EXPOSE 5672 15672

CMD ["/sbin/my_init"]
