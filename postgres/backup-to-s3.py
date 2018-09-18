# pip install humanize smart-open
# pass `--hush` to avoid output for each chunk

# jnm 20160925, 20161201, 20180517
import datetime
import humanize
import os
import re
import smart_open
import subprocess
import sys
from boto.s3.connection import S3Connection
from boto.utils import parse_ts

DBDATESTAMP = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')

#DATABASE_URL_PATTERN = (
#    r'postgis:\/\/(?P<username>[^:]+):(?P<password>[^@]+)@'
#    r'(?P<hostname>[^:]+):(?P<port>[^/]+)\/(?P<dbname>.+)$'
#)

# `postgis://` isn't recognized by `pg_dump`; replace it with `postgres://`
DBURL = re.sub(r'^postgis://', 'postgres://', os.getenv('DATABASE_URL'))
DUMPFILE = 'postgres-{}-{}-{}.pg_dump'.format(
    os.environ.get('PG_MAJOR'),
    os.environ.get('PUBLIC_DOMAIN_NAME'),
    DBDATESTAMP,
)
BACKUP_COMMAND = 'pg_dump --format=c --dbname="{}"'.format(DBURL)

DIRECTORIES = [
    {'name': 'yearly', 'keeps': 5, 'days': 365},
    {'name': 'monthly', 'keeps': 12, 'days': 30},
    {'name': 'weekly', 'keeps': 4, 'days': 7},
    {'name': 'daily', 'keeps': 30, 'days': 1},
]

# Consider backups invalid whose (compressed) size is below this number of
# bytes
MINIMUM_SIZE = 100 * 1024 ** 2

# Data will be written directly to S3
AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
AWS_BUCKET = os.environ.get('BACKUP_AWS_STORAGE_BUCKET_NAME')
CHUNK_SIZE = 250 * 1024 ** 2

###############################################################################

s3connection = S3Connection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
s3bucket = s3connection.get_bucket(AWS_BUCKET)

# Determine where to put this backup
now = datetime.datetime.now()
for directory in DIRECTORIES:
    prefix = directory['name'] + '/'
    earliest_current_date = now - datetime.timedelta(days=directory['days'])
    s3keys = s3bucket.list(prefix=prefix)
    large_enough_backups = filter(lambda x: x.size >= MINIMUM_SIZE, s3keys)
    young_enough_backup_found = False
    for backup in large_enough_backups:
        if parse_ts(backup.last_modified) >= earliest_current_date:
            young_enough_backup_found = True
    if not young_enough_backup_found:
        # This directory doesn't have any current backups; stop here and use it
        # as the destination
        break

# Perform the backup
filename = ''.join((prefix, DUMPFILE))
print 'Backing up to "{}"...'.format(filename)
upload = s3bucket.new_key(filename)
chunks_done = 0
with smart_open.smart_open(upload, 'wb') as s3backup:
    process = subprocess.Popen(
        BACKUP_COMMAND, shell=True, stdout=subprocess.PIPE)
    while True:
        chunk = process.stdout.read(CHUNK_SIZE)
        if not len(chunk):
            print 'Finished! Wrote {} chunks; {}'.format(
                chunks_done,
                humanize.naturalsize(chunks_done * CHUNK_SIZE)
            )
            break
        s3backup.write(chunk)
        chunks_done += 1
        if not '--hush' in sys.argv:
            print 'Wrote {} chunks; {}'.format(
                chunks_done,
                humanize.naturalsize(chunks_done * CHUNK_SIZE)
            )

# Remove old backups beyond desired retention
for directory in DIRECTORIES:
    prefix = directory['name'] + '/'
    keeps = directory['keeps']
    s3keys = s3bucket.list(prefix=prefix)
    large_enough_backups = filter(lambda x: x.size >= MINIMUM_SIZE, s3keys)
    large_enough_backups = sorted(large_enough_backups, key=lambda x: x.last_modified, reverse=True)

    for l in large_enough_backups[keeps:]:
        print 'Deleting old backup "{}"...'.format(l.name)
        l.delete()
