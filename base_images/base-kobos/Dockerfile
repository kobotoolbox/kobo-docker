FROM kobotoolbox/base:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

RUN apt-get -qq update && \
    apt-get -qq -y install \
        binutils \
        default-jre-headless \
        gdal-bin \
        libpcre3-dev \
        libpq-dev \
        libproj-dev \
        libxml2 \
        libxml2-dev \
        libxslt1-dev \
        libjpeg-dev \
        libffi-dev \
        npm \
        postgresql-client \
        python2.7-dev \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    curl -s https://bootstrap.pypa.io/get-pip.py | python && \
    pip install uwsgi && \
    useradd -s /bin/false -m wsgi

# Install Dockerize.
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz -P /tmp \
    && tar -C /usr/local/bin -xzvf /tmp/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm /tmp/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz
