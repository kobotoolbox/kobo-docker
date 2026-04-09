# -*- coding: utf-8 -*-
# pip install boto3
import datetime
import os
import subprocess
import sys

import boto3
from boto3.s3.transfer import TransferConfig

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
# `boto3` is used for both finding the final destination and uploading data
AWS_BUCKET = os.environ.get('BACKUP_AWS_STORAGE_BUCKET_NAME')

s3_client = boto3.client(
    's3'
)
###############################################################################

# Determine where to put this backup
now = datetime.datetime.now(datetime.timezone.utc)
for directory in DIRECTORIES:
    prefix = directory['name'] + '/'
    earliest_current_date = now - datetime.timedelta(days=directory['days'])
    response = s3_client.list_objects_v2(Bucket=AWS_BUCKET, Prefix=prefix)
    s3keys = response.get('Contents', [])
    large_enough_backups = [obj for obj in s3keys if obj['Size'] >= MINIMUM_SIZE]
    young_enough_backup_found = False
    for backup in large_enough_backups:
        if backup['LastModified'] >= earliest_current_date:
            young_enough_backup_found = True
    if not young_enough_backup_found:
        # This directory doesn't have any current backups; stop here and use it
        # as the destination
        break

# Perform the backup
filename = ''.join((prefix, DUMPFILE))
print('Backing up to "{}"...'.format(filename))

# Run the backup command
backup_result = subprocess.run(BACKUP_COMMAND, shell=True, capture_output=True, text=True)
if backup_result.returncode != 0:
    print(f"Backup command failed: {backup_result.stderr}")
    sys.exit(1)

# Upload to S3 using boto3
local_file_path = f"/srv/backups/{DUMPFILE}"
config = TransferConfig(
    multipart_threshold=8 * 1024 * 1024,  # 8MB
    max_concurrency=10,
    multipart_chunksize=CHUNK_SIZE * 1024 * 1024,  # Convert MB to bytes
    use_threads=True
)

try:
    s3_client.upload_file(
        local_file_path,
        AWS_BUCKET,
        filename,
        Config=config
    )
    print('Backup `{}` successfully sent to S3.'.format(filename))
except Exception as e:
    print(f"Failed to upload backup to S3: {e}")
    sys.exit(1)
finally:
    # Clean up local file
    if os.path.exists(local_file_path):
        os.remove(local_file_path)


aws_lifecycle = os.environ.get("AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED", "False") == "True"
if not aws_lifecycle:
    # Remove old backups beyond desired retention
    for directory in DIRECTORIES:
        prefix = directory['name'] + '/'
        keeps = directory['keeps']
        response = s3_client.list_objects_v2(Bucket=AWS_BUCKET, Prefix=prefix)
        s3keys = response.get('Contents', [])
        large_enough_backups = [obj for obj in s3keys if obj['Size'] >= MINIMUM_SIZE]
        large_enough_backups = sorted(large_enough_backups, key=lambda x: x['LastModified'], reverse=True)

        for backup in large_enough_backups[keeps:]:
            print('Deleting old backup "{}"...'.format(backup['Key']))
            s3_client.delete_object(Bucket=AWS_BUCKET, Key=backup['Key'])

print('Done!')
