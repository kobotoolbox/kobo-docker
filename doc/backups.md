# Mongo backups
## Enabling 
To schedule backups for mongo run this command inside the docker container: `MONGO_BACKUP_SCHEDULE="0 1 */1 * *" ./kobo-docker-scripts/toggle-backup-activation.sh`
    * By default it will write backups to the local disk path `/srv/backups`
    * Modify `MONGO_BACKUP_SCHEDULE` to a valid cron schedule, for example: `0 1 */1 * *` for once a day at 1AM UTC
    * To use S3 backups:
        * You need to have AWS credentials available in any method that [boto3](https://docs.aws.amazon.com/boto3/latest/guide/credentials.html#configuring-credentials) supports
            * To use an ec2 instance profile nothing needs done except changing the IMDS hop limit as noted below
            * To use static long lived credentials add `AWS_ACCESS_KEY_ID="value"` and `AWS_SECRET_ACCESS_KEY="value"` to the command
        * Add `BACKUP_AWS_STORAGE_BUCKET_NAME="bucketname"` with the appropriate bucketname to the command

## Disabling
To disable backups run this command within the mongo container: `./kobo-docker-scripts/toggle-backup-activation.sh`

# Redis backups
## Enabling
To schedule backups for redis run this command inside the docker container: `REDIS_BACKUP_SCHEDULE="0 1 */1 * *" ./kobo-docker-scripts/toggle-backup-activation.sh`
    * By default it will write backups to the local disk path `/srv/backups`
    * Modify `REDIS_BACKUP_SCHEDULE` to a valid cron schedule, for example: `0 1 */1 * *` for once a day at 1AM UTC
    * To use S3 backups:
        * You need to have AWS credentials available in any method that [boto3](https://docs.aws.amazon.com/boto3/latest/guide/credentials.html#configuring-credentials) supports
            * To use an ec2 instance profile nothing needs done except changing the IMDS hop limit as noted below
            * To use static long lived credentials add `AWS_ACCESS_KEY_ID="value"` and `AWS_SECRET_ACCESS_KEY="value"` to the command
        * Add `BACKUP_AWS_STORAGE_BUCKET_NAME="bucketname"` with the appropriate bucketname to the command

## Disabling
To disable backups run this command within the redis container: `./kobo-docker-scripts/toggle-backup-activation.sh`

# Postgres backups
## Enabling
To schedule backups for postgres run this command inside the docker container: `POSTGRES_BACKUP_SCHEDULE="0 1 */1 * *" ./kobo-docker-scripts/scripts/toggle-backup-activation.sh`
    * By default it will write backups to the local disk path `/srv/backups`
    * Modify `POSTGRES_BACKUP_SCHEDULE` to a valid cron schedule, for example: `0 1 */1 * *` for once a day at 1AM UTC
    * To use S3 backups:
        * You need to have AWS credentials available in any method that [boto3](https://docs.aws.amazon.com/boto3/latest/guide/credentials.html#configuring-credentials) supports
            * To use an ec2 instance profile nothing needs done except changing the IMDS hop limit as noted below
            * To use static long lived credentials add `AWS_ACCESS_KEY_ID="value"` and `AWS_SECRET_ACCESS_KEY="value"` to the command
        * Add `BACKUP_AWS_STORAGE_BUCKET_NAME="bucketname"` with the appropriate bucketname to the command

## Disabling
To disable backups run this command within the postgres container: `./kobo-docker-scripts/scripts/toggle-backup-activation.sh`

# Backing up to AWS
The user or role that performs the backups must have the following permissions to the bucket, update `bucketname` as appropriate.
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowBackups",
            "Effect": "Allow",
            "Action": [
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::bucketname",
                "arn:aws:s3:::bucketname/*"
            ]
        }
    ]
}
```

If you are using an ec2 instance profile IAM role the instance must have its metadata [put response hop limit](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-IMDS-existing-instances.html#modify-PUT-response-hop-limit) set to 2 or greater
