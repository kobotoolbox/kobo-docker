FROM kobotoolbox/base:latest

# Copy over the list of `apt` requirements and install them using Postgres's repo.
RUN mkdir -p /srv/tmp
COPY ./apt_requirements.txt /srv/tmp/
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' > /etc/apt/sources.list.d/pgdg.list && \
    curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get -qq update && \
    apt-get -qq -y install $(cat /srv/tmp/apt_requirements.txt) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
