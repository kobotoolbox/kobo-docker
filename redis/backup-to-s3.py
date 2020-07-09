# -*- coding: utf-8 -*-
import datetime
import os
import sys

from boto.s3.connection import S3Connection
from boto.utils import parse_ts

DBDATESTAMP = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')

DUMPFILE = 'redis-{}-{}-{}.gz'.format(
    os.environ.get('REDIS_VERSION'),
    os.environ.get('PUBLIC_DOMAIN_NAME'),
    DBDATESTAMP,
)

BACKUP_COMMAND = "$(command -v bash) /kobo-docker-scripts/backup-to-disk.bash {}".format(
    DUMPFILE
)

yearly_retention = int(os.environ.get("AWS_BACKUP_YEARLY_RETENTION", 2))
monthly_retention = int(os.environ.get("AWS_BACKUP_MONTHLY_RETENTION", 12))
weekly_retention = int(os.environ.get("AWS_BACKUP_WEEKLY_RETENTION", 4))
daily_retention = int(os.environ.get("AWS_BACKUP_DAILY_RETENTION", 30))


DIRECTORIES = [
    {'name': 'redis/yearly', 'keeps': yearly_retention, 'days': 365},
    {'name': 'redis/monthly', 'keeps': monthly_retention, 'days': 30},
    {'name': 'redis/weekly', 'keeps': weekly_retention, 'days': 7},
    {'name': 'redis/daily', 'keeps': daily_retention, 'days': 1},
]

# Consider backups invalid whose (compressed) size is below this number of
# bytes
MINIMUM_SIZE = int(os.environ.get("AWS_REDIS_BACKUP_MINIMUM_SIZE", 100)) * 1024 ** 2

# In MB
CHUNK_SIZE = int(os.environ.get("AWS_BACKUP_CHUNK_SIZE", 250))

# Data will be written directly to S3
# `s3cmd` is used to push data to s3, but `boto` is used to find the final
# destination
AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
AWS_BUCKET = os.environ.get('BACKUP_AWS_STORAGE_BUCKET_NAME')

s3connection = S3Connection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
s3bucket = s3connection.get_bucket(AWS_BUCKET)
###############################################################################

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
print('Backing up to "{}"...'.format(filename))

s3cmd = os.path.join(os.path.dirname(sys.executable), 's3cmd')
os.system("{backup_command} && {s3cmd} put --multipart-chunk-size-mb={chunk_size}"
          " /srv/backups/{source} s3://{bucket}/{filename}"
          " && rm -rf /srv/backups/{source}".format(
    s3cmd=s3cmd,
    backup_command=BACKUP_COMMAND,
    bucket=AWS_BUCKET,
    chunk_size=CHUNK_SIZE,
    filename=filename,
    source=DUMPFILE
))

print('Backup `{}` successfully sent to S3.'.format(filename))


aws_lifecycle = os.environ.get("AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED", "False") == "True"
if not aws_lifecycle:
    # Remove old backups beyond desired retention
    for directory in DIRECTORIES:
        prefix = directory['name'] + '/'
        keeps = directory['keeps']
        s3keys = s3bucket.list(prefix=prefix)
        large_enough_backups = filter(lambda x: x.size >= MINIMUM_SIZE, s3keys)
        large_enough_backups = sorted(large_enough_backups, key=lambda x: x.last_modified, reverse=True)

        for l in large_enough_backups[keeps:]:
            print('Deleting old backup "{}"...'.format(l.name))
            l.delete()

print('Done!')
