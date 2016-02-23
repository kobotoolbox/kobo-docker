FROM kobotoolbox/base-kobos:docker_local

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

# Install `apt` dependencies.
# FIXME: Use the `ADD` instead of `COPY` once `kobocat`'s `docker_local` branch has been merged.
# ADD https://github.com/kobotoolbox/kobocat/raw/master/apt_requirements.txt
COPY ./apt_requirements.txt /tmp/kobocat_apt_requirements.txt
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y $(cat /tmp/kobocat_apt_requirements.txt) && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install https://bitbucket.org/fomcl/savreaderwriter/downloads/savReaderWriter-3.3.0.zip#egg=savreaderwriter && \
    pip install dj-database-url && \
    mkdir -p /srv/src && \
    cd /srv/src && \
    git clone --depth 1 https://github.com/kobotoolbox/kobocat.git -b master && \
    git clone --depth 1 https://github.com/kobotoolbox/kobocat-template.git -b master && \
    pip install -r /srv/src/kobocat/requirements/base.pip && \
    pip install -r /srv/src/kobocat/requirements/s3.pip && \
    pip install raven==5.2.0 && \
    chown -R wsgi /srv/src/kobocat*
