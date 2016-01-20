#!/bin/bash

oldpwd=$(pwd)
cd /srv/src/kobocat

mkdir -p /srv/src/kobocat/onadata/static

echo "Collecting static files..."
python manage.py collectstatic -v 0 --noinput
echo "Done"
echo "Fixing permissions..."
chown -R wsgi /srv/src/kobocat
echo "Done."
echo "Syncing to nginx folder..."
rsync -aq /srv/src/kobocat/onadata/static/* /srv/static/
echo "Done"

cd $oldpwd
