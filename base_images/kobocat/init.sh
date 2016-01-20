#!/bin/bash

oldpwd=$(pwd)
cd /srv/src/kobocat

psql -h db -p ${PSQL_PORT} -U ${KOBO_PSQL_DB_USER} ${KOBO_PSQL_DB_NAME} -c "create extension postgis; create extension postgis_topology"
 
python manage.py syncdb --noinput

python manage.py migrate --noinput

cd $oldpwd
