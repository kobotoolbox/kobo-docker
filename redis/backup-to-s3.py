# -*- coding: utf-8 -*-
import datetime
import os
import subprocess
import sys

import boto3
import humanize
import smart_open

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

# Data will be written directly to S3
AWS_BUCKET = os.environ.get("BACKUP_AWS_STORAGE_BUCKET_NAME")
CHUNK_SIZE = int(os.environ.get("AWS_BACKUP_CHUNK_SIZE", 250)) * 1024**2

###############################################################################


def run():
    """
    Backup redis database.
    """

    s3 = boto3.resource('s3')
    bucket = s3.Bucket(AWS_BUCKET)

    # Determine where to put this backup
    now = datetime.datetime.now(datetime.timezone.utc)

    for directory in DIRECTORIES:
        prefix = directory["name"] + "/"
        earliest_current_date = now - datetime.timedelta(days=directory["days"])
        s3keys = list(bucket.objects.filter(Prefix=prefix))
        large_enough_backups = filter(lambda x: x.size >= MINIMUM_SIZE, s3keys)
        young_enough_backup_found = False
        for backup in large_enough_backups:
            if backup.last_modified >= earliest_current_date:
                young_enough_backup_found = True
        if not young_enough_backup_found:
            # This directory doesn't have any current backups; stop here and use it
            # as the destination
            break

    # Perform the backup
    filename = "".join((prefix, DUMPFILE))
    print('Backing up to "{}"...'.format(filename))
    chunks_done = 0
    with smart_open.smart_open('s3://{}/{}'.format(AWS_BUCKET, filename), "wb") as s3backup:
        process = subprocess.Popen(BACKUP_COMMAND, shell=True, stdout=subprocess.PIPE)
        while True:
            chunk = process.stdout.read(CHUNK_SIZE)
            if not len(chunk):
                print(
                    "Finished! Wrote {} chunks; {}".format(
                        chunks_done, humanize.naturalsize(chunks_done * CHUNK_SIZE)
                    )
                )
                break
            s3backup.write(chunk)
            chunks_done += 1
            if "--hush" not in sys.argv:
                print(
                    "Wrote {} chunks; {}".format(
                        chunks_done, humanize.naturalsize(chunks_done * CHUNK_SIZE)
                    )
                )

    print("Backup `{}` successfully sent to S3.".format(filename))


def cleanup():
    aws_lifecycle = (
        os.environ.get("AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED", "False") == "True"
    )

    s3 = boto3.resource('s3')
    bucket = s3.Bucket(AWS_BUCKET)

    if not aws_lifecycle:
        # Remove old backups beyond desired retention
        for directory in DIRECTORIES:
            prefix = directory["name"] + "/"
            keeps = directory["keeps"]
            s3keys = list(bucket.objects.filter(Prefix=prefix))
            large_enough_backups = filter(lambda x: x.size >= MINIMUM_SIZE, s3keys)
            large_enough_backups = sorted(
                large_enough_backups, key=lambda x: x.last_modified, reverse=True
            )

            for l in large_enough_backups:
                now = datetime.datetime.now(datetime.timezone.utc)
                delta = now - l.last_modified
                if delta.days > keeps:
                    print('Deleting old backup "{}"...'.format(l.key))
                    l.delete()


run()
cleanup()

print("Done!")
