FROM teodorescuserban/kobo-base-kobos:latest

MAINTAINER Serban Teodorescu, teodorescu.serban@gmail.com

# moved to base-kobos
#RUN apt-get -qq update && \
#    apt-get -qq -y install \
#        default-jre-headless && \
#    apt-get clean && \
#    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \

RUN mkdir -p /srv/src && \
    cd /srv/src && \
    git clone https://github.com/kobotoolbox/dkobo.git -b master koboform && \
    cd /srv/src/koboform && \
    pip install -r requirements.txt && \
    pip install raven==5.2.0 && \
    npm --no-color install \
        yuglify && \
    chown -R wsgi /srv/src/koboform
