FROM teodorescuserban/kobo-base:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

RUN apt-get -qq update && \
    apt-get -qq -y install \
        binutils \
        default-jre-headless \
        gdal-bin \
        libmemcached-dev \
        libpcre3-dev \
        libpq-dev \
        libproj-dev \
        libxml2 \
        libxml2-dev \
        libxslt1-dev \
        libjpeg-dev \
        nodejs \
        npm \
        postgresql-client-9.3 \
        python2.7-dev \
        python-qgis \
        qgis && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    ln -s /usr/bin/nodejs /usr/bin/node && \
    mkdir -p /etc/service/wsgi && \
    touch /etc/service/wsgi/run && \
    curl -s https://bootstrap.pypa.io/get-pip.py -o /get-pip.py && \
    python /get-pip.py && \
    rm /get-pip.py && \
    pip install uwsgi && \
    useradd -s /bin/false -m wsgi && \
    mkdir -p /usr/local/lib/node_modules && \
    chown -R wsgi /usr/local/lib/node_modules && \
    npm --no-color install -g \
        bower \
        karma \
        grunt-cli
