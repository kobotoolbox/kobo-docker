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
    # FIXME: Temporarily install `pip` < v8.1.2 until `pip-tools` is compatible.
    pip install --upgrade pip==8.1.1 && \
    pip install uwsgi && \
    useradd -s /bin/false -m wsgi

# Install Dockerize.
RUN wget https://github.com/jwilder/dockerize/releases/download/v0.2.0/dockerize-linux-amd64-v0.2.0.tar.gz -P /tmp
RUN tar -C /usr/local/bin -xzvf /tmp/dockerize-linux-amd64-v0.2.0.tar.gz
