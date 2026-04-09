# pip install boto3

import datetime
import os
import re
import subprocess
import sys
from threading import Thread

import boto3


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
AWS_BUCKET = os.environ.get('BACKUP_AWS_STORAGE_BUCKET_NAME')
CHUNK_SIZE = int(os.environ.get("AWS_BACKUP_CHUNK_SIZE", 250)) * 1024 ** 2

s3_client = boto3.client('s3')

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

        local_file_path = f"/tmp/{DUMPFILE}"
        BACKUP_COMMAND = 'pg_dump --format=c --dbname="{}" > "{}"'.format(DBURL, local_file_path)

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
        try:
            s3_client.upload_file(local_file_path, AWS_BUCKET, filename)
            print('Backup `{}` successfully sent to S3.'.format(filename))
        except Exception as e:
            print(f"Failed to upload backup to S3: {e}")
            sys.exit(1)
        finally:
            # Clean up local file
            if os.path.exists(local_file_path):
                os.remove(local_file_path)

        return  # Close thread


def cleanup():
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

            for l in large_enough_backups[keeps:]:
                print('Deleting old backup "{}"...'.format(l['Key']))
                s3_client.delete_object(Bucket=AWS_BUCKET, Key=l['Key'])


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
