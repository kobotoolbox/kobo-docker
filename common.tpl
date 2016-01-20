# copyleft 2015 teodorescu.serban@gmail.com

rabbit:
  image: kobotoolbox/rabbit:latest
  # build: ./base_images/rabbit
  hostname: rabbit
  env_file:
    - ./env_common
  environment:
    - RABBITMQ_LOGS=-
    - RABBITMQ_SASL_LOGS=-
  ports:
    - "${RABBIT_HOST}:${RABBIT_PORT}:5672"
#    - "${RABBIT_HOST}:${RABBIT_MGMT_PORT}:15672"

psql:
  image: kobotoolbox/psql:latest
  # build: ./base_images/psql
  hostname: psql
  env_file:
    - ./env_common
    - ./env_sql
  ports:
    - "${PSQL_HOST}:${PSQL_PORT}:5432"
  volumes:
    - "${VOL_DB}/db:/srv/db"

mongo:
  image: kobotoolbox/mongo:latest
  # build: ./base_images/mongo
  hostname: mongo
  env_file:
    - ./env_common
  environment:
    - MONGO_DATA=/srv/db
  ports:
    - "${MONGO_HOST}:${MONGO_PORT}:27017"
  volumes:
    - "${VOL_DB}/mongo:/srv/db"

kobocat:
  image: kobotoolbox/kobocat:latest # still WIP
  # build: ./base_images/kobocat
  hostname: kobocat
  env_file:
    - ./env_common
    - ./env_sql
    - ./env_kobos
    - ./env_kobocat
  ports:
    - "${KOBOCAT_SERVER_ADDR}:${KOBOCAT_SERVER_PORT}:8000"
  extra_hosts:
    - "db: ${PSQL_HOST}"
    - "mongo: ${MONGO_HOST}"
    - "rabbit: ${RABBIT_HOST}"
  volumes:
    - "${VOL_WB}/static/kobocat:/srv/static"

dkobo:
  image: kobotoolbox/dkobo:latest # still WIP
  # build: ./base_images/dkobo
  hostname: dkobo
  env_file:
    - ./env_common
    - ./env_sql
    - ./env_kobos
    - ./env_dkobo
  ports:
    - "${KOBOFORM_SERVER_ADDR}:${KOBOFORM_SERVER_PORT}:8000"
  extra_hosts:
    - "db: ${PSQL_HOST}"
    - "${KOBOFORM_PUBLIC_ADDR}: ${KOBO_WB_SERVER_IP}"
    - "${KOBOCAT_PUBLIC_ADDR}: ${KOBO_WB_SERVER_IP}"
  volumes:
    - "${VOL_WB}/static/koboform:/srv/static"

kpi:
  image: kobotoolbox/kpi:latest
  hostname: kpi
  env_file:
    - ./env_common
    - ./env_sql
    - ./env_kobos
    - ./env_kpi
  ports:
    - "${KPI_SERVER_ADDR}:${KPI_SERVER_PORT}:8000"
  extra_hosts:
    - "db: ${PSQL_HOST}"
    - "${KOBOFORM_PUBLIC_ADDR}: ${KOBO_WB_SERVER_IP}"
    - "${KOBOCAT_PUBLIC_ADDR}: ${KOBO_WB_SERVER_IP}"
  volumes:
    - "${VOL_WB}/static/kpi:/srv/static"
    # The Whoosh search index needs persistent storage
    - "${VOL_DB}/whoosh:/srv/whoosh"

web:
  image: kobotoolbox/nginx:latest # still WIP
  # build: ./base_images/nginx
  hostname: nginx
  env_file:
    - ./env_common
    - ./env_nginx
  #  - ./env_secrets
  ports:
    - "${KOBO_WB_SERVER_IP}:${NGINX_HTTP_PORT}:80"
    - "${KOBO_WB_SERVER_IP}:${NGINX_HTTPS_PORT}:443"
  volumes:
      - "${VOL_WB}/static:/srv/www:ro"
      # get the logs out of glusterfs!
      - "${VOL_WB}/../log/nginx:/var/log/nginx"
  extra_hosts:
    - "${KOBOFORM_PUBLIC_ADDR}: ${KOBO_WB_SERVER_IP}"
    - "${KOBOCAT_PUBLIC_ADDR}: ${KOBO_WB_SERVER_IP}"
