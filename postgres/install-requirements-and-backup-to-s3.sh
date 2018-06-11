#!/bin/sh -e

echo 'Installing requirements...'
apt-get update --quiet=2
apt-get install --quiet=2 python-pip > /dev/null
pip install  --quiet humanize==0.5.1 smart-open==1.5.7

echo 'Launching backup script...'
python /kobo-docker-scripts/backup-to-s3.py
