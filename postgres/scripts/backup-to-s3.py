# pip install humanize smart-open
# pass `--hush` to avoid output for each chunk

# jnm 20160925, 20161201, 20180517
import datetime
import os
import re
import subprocess
import sys
from threading import Thread

import humanize
import smart_open
from boto.s3.connection import S3Connection
from boto.utils import parse_ts


APP_CODES = {
    'kpi': os.getenv('KPI_DATABASE_URL'),
    'kc': os.getenv('KC_DATABASE_URL'),
}

yearly_retention = int(os.environ.get("AWS_BACKUP_YEARLY_RETENTION", 2))
monthly_retention = int(os.environ.get("AWS_BACKUP_MONTHLY_RETENTION", 12))
weekly_retention = int(os.environ.get("AWS_BACKUP_WEEKLY_RETENTION", 4))
daily_retention = int(os.environ.get("AWS_BACKUP_DAILY_RETENTION", 30))

DIRECTORIES = [
    {'name': 'postgres/yearly', 'keeps': yearly_retention, 'days': 365},
    {'name': 'postgres/monthly', 'keeps': monthly_retention, 'days': 30},
    {'name': 'postgres/weekly', 'keeps': weekly_retention, 'days': 7},
    {'name': 'postgres/daily', 'keeps': daily_retention, 'days': 1},
]

# Consider backups invalid whose (compressed) size is below this number of
# bytes
MINIMUM_SIZE = int(os.environ.get("AWS_POSTGRES_BACKUP_MINIMUM_SIZE", 100)) * 1024 ** 2

# Data will be written directly to S3
AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
AWS_BUCKET = os.environ.get('BACKUP_AWS_STORAGE_BUCKET_NAME')
CHUNK_SIZE = int(os.environ.get("AWS_BACKUP_CHUNK_SIZE", 250)) * 1024 ** 2

###############################################################################


class Backup(Thread):

    def __init__(self, app_code_):
        """
        Args:
            app_code_ (str): `kc` or `kpi`
        """
        self.__app_code = app_code_
        super().__init__()

    def run(self):
        """
        Backup postgres database for specific `app_code`.
        """

        s3connection = S3Connection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
        s3bucket = s3connection.get_bucket(AWS_BUCKET)

        DBDATESTAMP = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')

        # `postgis://` isn't recognized by `pg_dump`; replace it with `postgres://`
        DBURL = re.sub(r'^postgis://', 'postgres://', APP_CODES.get(self.__app_code))
        # Because we are running `pg_dump` within the container,
        # we need to replace the hostname ...
        DBURL = DBURL.replace(os.getenv("POSTGRES_HOST"), "127.0.0.1")
        # ... and the port for '127.0.0.1:5432'
        DBURL = re.sub(r"\:(\d+)\/", ":5432/", DBURL)

        DUMPFILE = 'postgres-{}-{}-{}-{}.pg_dump'.format(
            self.__app_code,
            os.environ.get('PG_MAJOR'),
            os.environ.get('PUBLIC_DOMAIN_NAME'),
            DBDATESTAMP,
        )

        BACKUP_COMMAND = 'pg_dump --format=c --dbname="{}"'.format(DBURL)

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
        upload = s3bucket.new_key(filename)
        chunks_done = 0
        with smart_open.smart_open(upload, 'wb') as s3backup:
            process = subprocess.Popen(
                BACKUP_COMMAND, shell=True, stdout=subprocess.PIPE)
            while True:
                chunk = process.stdout.read(CHUNK_SIZE)
                if not len(chunk):
                    print('Finished! Wrote {} chunks; {}'.format(
                        chunks_done,
                        humanize.naturalsize(chunks_done * CHUNK_SIZE)
                    ))
                    break
                s3backup.write(chunk)
                chunks_done += 1
                if '--hush' not in sys.argv:
                    print('Wrote {} chunks; {}'.format(
                        chunks_done,
                        humanize.naturalsize(chunks_done * CHUNK_SIZE)
                    ))

        print('Backup `{}` successfully sent to S3.'.format(filename))
        return  # Close thread


def cleanup():
    aws_lifecycle = os.environ.get("AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED", "False") == "True"

    s3connection = S3Connection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    s3bucket = s3connection.get_bucket(AWS_BUCKET)

    if not aws_lifecycle:
        # Remove old backups beyond desired retention
        for directory in DIRECTORIES:
            prefix = directory['name'] + '/'
            keeps = directory['keeps']
            s3keys = s3bucket.list(prefix=prefix)
            large_enough_backups = filter(lambda x: x.size >= MINIMUM_SIZE, s3keys)
            large_enough_backups = sorted(large_enough_backups, key=lambda x: x.last_modified, reverse=True)

            for l in large_enough_backups:
                now = datetime.datetime.now()
                delta = now - parse_ts(l.last_modified)
                if delta.days > keeps:
                    print('Deleting old backup "{}"...'.format(l.name))
                    l.delete()


database_urls = set(APP_CODES.values())
# Avoid backup twice the same DB
if len(database_urls) == 1:
    backup = Backup('kc')
    backup.start()
else:
    threads = []
    for app_code in APP_CODES.keys():
        backup = Backup(app_code)
        backup.start()
        threads.append(backup)

    for thread_ in threads:
        thread_.join()

cleanup()

print('Done!')
