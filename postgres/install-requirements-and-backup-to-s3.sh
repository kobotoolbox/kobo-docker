#!/bin/sh -e

echo 'Installing requirements...'
apt-get update --quiet=2
apt-get install --quiet=2 python-virtualenv > /dev/null
virtualenv env
. env/bin/activate
pip install  --quiet humanize smart-open

echo 'Launching backup script...'
python /kobo-docker-scripts/backup-to-s3.py
