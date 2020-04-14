# kobo-docker

1. [Introduction](#introduction)
1. [_Two PostgreSQL databases are now required_](#two-postgresql-databases-are-now-required)
1. [Important notice when upgrading from commit `5c2ef02` (March 4, 2019) or earlier](#important-notice-when-upgrading-from-commit-5c2ef02-march-4-2019-or-earlier)
1. [Architecture](#architecture)
1. [Setup procedure](#setup-procedure)
1. [Usage](#usage)
    - Start/stop
    - Backups
    - Restore backups
    - Maintenance
1. [Troubleshooting](#troubleshooting)
1. [Redis performance](#redis-performance)


## Introduction

kobo-docker is used to run a copy of the [KoBoToolbox](http://www.kobotoolbox.org) survey data collection platform on a machine of your choosing. It relies on [Docker](https://docker.com) to separate the different parts of KoBo into different containers (which can be thought of as lighter-weight virtual machines) and [Docker Compose](https://docs.docker.com/compose/) to configure, run, and connect those containers.


## _Two PostgreSQL databases are now required_

Up to and including release [`2.019.52-final-shared-database`](https://github.com/kobotoolbox/kobo-docker/releases/tag/2.019.52-final-shared-database),
[KPI](https://github.com/kobotoolbox/kpi) and
[KoBoCAT](https://github.com/kobotoolbox/kobocat) both shared a common Postgres
database. They now each have their own, separate databases.
**If you are upgrading an existing single-database installation, you must follow [these instructions](https://community.kobotoolbox.org/t/upgrading-to-separate-databases-for-kpi-and-kobocat/7202)** to migrate the KPI tables to a new database and adjust your configuration appropriately.
This assumes your last upgrade was **more recent** than March 4, 2019. If not, you must [upgrade your databases](#important-notice-when-upgrading-from-commit-5c2ef02-march-4-2019-or-earlier) before proceeding.


## Important notice when upgrading from commit [`5c2ef02` (March 4, 2019)](https://github.com/kobotoolbox/kobo-docker/commit/5c2ef0273339bee5c374830f72e52945947042a8) or earlier

Running current releases of KoBoToolbox requires you to upgrade your Postgres and Mongo databases. Please follow [these instructions](./doc/March-2019-Upgrade.md).

If you do not, the application may not start or your data may not be visible.


## Architecture

Below is a diagram (made with [Lucidchart](https://www.lucidchart.com)) of the containers that make up a running kobo-docker system and their connections.

![Diagram of Docker Containers](./doc/container-diagram.svg)

### Secure your installation!
kobo-docker **opens ports on all interfaces** to let the `frontend` containers communicate with `backend` containers.
A firewall is **HIGHLY recommended**. You **MUST** block PostgreSQL, Redis and MongoDB ports when the server is exposed publicly.


## Setup procedure

This procedure has been simplified by using [kobo-install](https://github.com/kobotoolbox/kobo-install "").
Please use it to install kobo-docker.

Already have an existing installation? Please see below.

1. **Migrating from RabbitMQ to Redis as the Celery (asynchronous task) broker**

    The easiest way is to rely on [kobo-install](https://github.com/kobotoolbox/kobo-install) to generate the correct environment files.

    If you want to change it manually, edit:

    - `kobo-deployments/envfiles/kpi.txt`
        ```diff
        - KPI_BROKER_URL=amqp://kpi:kpi@rabbit.[internal domain name]:5672/kpi
        + KPI_BROKER_URL=redis://redis-main.[internal domain name]:6389/1
        ```
    - `kobo-deployments/envfiles/kobocat.txt`
        ```diff
        - KOBOCAT_BROKER_URL=amqp://kobocat: kobocat@rabbit.[internal domain name]:5672/kobocat
        + KOBOCAT_BROKER_URL =redis://redis-main.[internal domain name]:6389/2`
        ```

2. **Load balancing and redundancy**

    1. Load balancing
        kobo-docker has two different composer files. One for `frontend` and one for `backend`.

        1. `frontend`:
            - NGINX
            - [KoBoCAT](https://github.com/kobotoolbox/kobocat)
            - [KPI](https://github.com/kobotoolbox/kpi)
            - [Enketo Express](https://github.com/enketo/enketo-express)

        2. `backend`:
            - PostgreSQL
            - MongoDB
            - Redis

        Docker-compose for `frontend` can be started on its own server, same thing for `backend`. Users can start as many `frontend` servers they want. A load balancer can spread the traffic between `frontend` servers.
        kobo-docker uses (private) domain names between `frontend` and `backend`.
        It's fully customizable in configuration files. Once again, [kobo-install](https://github.com/kobotoolbox/kobo-install) does simplify the job by creating the configuration files for you.

    2. Redundancy
        `Backend` containers not redundant yet. Only `PostgreSQL` can be configured in `Master/Slave` mode where `Slave` is a real-time read-only replica.

    This is a diagram that shows how kobo-docker can be used for a load-balanced/(almost) redundant solution.

    _NB: The diagram is based on AWS infrastructure, but it's not required to host your environment there._

    ![aws diagram](./doc/aws-diagram.svg)

## Usage
It's recommended to create `*.override.yml` docker-compose files to customize your environment. It makes easier to update.

- `docker-compose.frontend.override.yml`
- `docker-compose.backend.master.override.yml`
- `docker-compose.backend.slave.override.yml` (if a postgres replica is used)

1. **Start/start containers**
    ```
    $kobo-docker> docker-compose -f docker-compose.frontend.yml [-f docker-compose.frontend.override.yml] up -d
    $kobo-docker> docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] up -d
    $kobo-docker> docker-compose -f docker-compose.frontend.yml [-f docker-compose.frontend.override.yml] stop
    $kobo-docker> docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] stop
    ```


2. **Backups**

    Automatic, periodic backups of KoBoCAT media, MongoDB, PostgreSQL and Redis can be individually enabled by uncommenting (and optionally customizing) the `*_BACKUP_SCHEDULE` variables in your envfiles.

     - `deployments/envfiles/databases.txt` (MongoDB, PostgreSQL, Redis)
     - `deployments/envfiles/kobocat.txt` (KoBoCat media)

    When enabled, timestamped backups will be placed in backups/kobocat, backups/mongo, backups/postgres and backups/redis respectively.

    If `AWS` credentials and `AWS S3` backup bucket name are provided, the backups are created directly on `S3`.

    Backups **on disk** can also be manually triggered when kobo-docker is running by executing the the following commands:

    ```
    $kobo-docker> docker-compose -f docker-compose.frontend.yml [-f docker-compose.frontend.override.yml] exec kobocat /srv/src/kobocat/docker/backup_media.bash
    $kobo-docker> docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] exec mongo /bin/bash /kobo-docker-scripts/backup-to-disk.bash
    $kobo-docker> docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] exec -e PGUSER=kobo postgres /bin/bash /kobo-docker-scripts/backup-to-disk.bash
    $kobo-docker> docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] exec redis_main /bin/bash /kobo-docker-scripts/backup-to-disk.bash
    ```

2. **Restore backups**

    Commands should be run within containers.

     - MongoDB: `mongorestore --archive=<path/to/mongo.backup.gz> --gzip`
     - PostgreSQL: `pg_restore -U kobo -d kobotoolbox -c "<path/to/postgres.pg_dump>"`
     - Redis: `gunzip <path/to/redis.rdb.gz> && mv <path/to/extracted_redis.rdb> /data/enketo-main.rdb`

3. **Maintenance mode**

    There is one composer file `docker-compose.maintenance.yml` can be used to put `KoBoToolbox` in maintenance mode.

    `nginx` container has to be stopped before launching the maintenance container.

    **Start**

    ```
    docker-compose -f docker-compose.frontend.yml [-f docker-compose.frontend.override.yml] stop nginx
    docker-compose -f docker-compose.maintenance.yml up -d
    ```

    **Stop**

    ```
    docker-compose -f docker-compose.maintenance.yml down
    docker-compose -f docker-compose.frontend.yml [-f docker-compose.frontend.override.yml] up -d nginx
    ```

    There are 4 variables that can be customized in `docker-compose.maintenance.yml`

    - `ETA` e.g. `2 hours`
    - `DATE_STR` e.g. `Monday, November 26 at 02:00 GMT`
    - `DATE_ISO` e.g. `20181126T02`
    - `EMAIL` e.g. `support@example.com`

## Troubleshooting

- ### Basic troubleshooting
    You can confirm that your containers are running with `docker ps`.
    To inspect the log output from:

     - the frontend containers, execute `docker-compose -f docker-compose.frontend.yml [-f docker-compose.frontend.override.yml] logs -f`
     - the master backend containers, execute `docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] logs -f`
     - the slaved backend container, execute `docker-compose -f docker-compose.backend.slave.yml [-f docker-compose.backend.slave.override.yml] logs -f`

    For a specific container use e.g. `docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] logs -f redis_main`.

    The documentation for Docker can be found at https://docs.docker.com.

- ### Django debugging
    Developers can use [PyDev](http://www.pydev.org/)'s [remote, graphical Python debugger](http://www.pydev.org/manual_adv_remote_debugger.html) to debug Python/Django code. To enable for the `kpi` container:

    1. Specify the mapping(s) between target Python source/library paths on the debugging machine to the locations of those files/directories inside the container by customizing and uncommenting the `KPI_PATH_FROM_ECLIPSE_TO_PYTHON_PAIRS` variable in [`envfiles/kpi.txt`](./envfiles/kpi.txt).
    2. Share the source directory of the PyDev remote debugger plugin into the container by customizing (taking care to note the actual location of the version-numbered directory) and uncommenting the relevant `volumes` entry in your `docker-compose.yml`.
    3. To ensure PyDev shows you the same version of the code as is being run in the container, share your live version of any target Python source/library files/directories into the container by customizing and uncommenting the relevant `volumes` entry in your `docker-compose.yml`.
    4. Start the PyDev remote debugger server and ensure that no firewall or other settings will prevent the containers from connecting to your debugging machine at the reported port.
    5. Breakpoints can be inserted with e.g. `import pydevd; pydevd.settrace('${DEBUGGING_MACHINE_IP}')`.

    Remote debugging in the `kobocat` container can be accomplished in a similar manner.


## Redis performance
Please take a look at [https://www.techandme.se/performance-tips-for-redis-cache-server/](https://www.techandme.se/performance-tips-for-redis-cache-server/)
to get rid of Warning message when starting redis containers
