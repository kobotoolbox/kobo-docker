#!/usr/bin/env bash
set -e

timestamp="$(date +%Y.%m.%d.%H_%M)"
cd /srv/backups
rm -rf dump
mongodump
tar -czf "mongo_backup__${timestamp}.mongorestore.tar.gz" dump
rm -rf dump
