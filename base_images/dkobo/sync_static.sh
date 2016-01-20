#!/bin/bash

export PATH=$PATH:./node_modules/.bin

oldpwd=$(pwd)
cd /srv/src/koboform

echo "Collecting static files..."
mkdir -p /srv/src/koboform/staticfiles
python manage.py collectstatic --noinput -c -v 0
grunt build_all
#npm install yuglify
python manage.py compress
mkdir -p jsapp/CACHE
cp -R jsapp/components/fontawesome/fonts jsapp/CACHE/fonts
python manage.py collectstatic --noinput -v 0
echo "Done."

echo "Fixing permissions..."
chown -R wsgi /srv/src/koboform
echo "Done."

echo "Syncing to nginx folder..."
rsync -aq  /srv/src/koboform/staticfiles/* /srv/static/
echo "Done."

cd $oldpwd
