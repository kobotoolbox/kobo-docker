## kobo-docker

`kobo-docker` is used to run a copy of the [KoBo Toolbox](http://www.kobotoolbox.org) survey data collection platform on a machine of your choosing. It relies on [Docker](https://docker.com) to separate the different parts of KoBo into different containers (which can be thought of as lighter-weight virtual machines) and [Docker Compose](https://docs.docker.com/compose/) to configure, run, and connect those containers. 
Below is a diagram (made with [Lucidchart](lucidchart.com)) of the containers that make up a running `kobo-docker` system and their connections. 

![Container diagram](./doc/Container_diagram.png)


## Setup procedure:

This procedure has been simplified by using [`kobo-install`](https://github.com/kobotoolbox/kobo-install ""). 
Please use it to install `kobo-docker`.   
Already have an existing installation? Please see below.

## Upgrading from an old version of `kobo-docker` (before to Dec'2018)
Latest version of `kobo-docker` use `PostgreSQL 9.5` and `MongoDB 3.4`. 

If you already run an older version of `kobo-docker`, you need to upgrade to these version first before using this version (or `kobo-install`).  
This is a step-by-step procedure to upgrade `PostgreSQL` and `MongoDB` containers.

### PostgreSQL
**To upgrade to PostgresSQL 9.5, you will need to have twice the space of the database size.**  
**Be sure to have enough space left on the host filesystem before upgrading.**


1. Stop the containers
   
   ```
   docker-compose stop
   ```

2. Edit composer file `docker-compose.yml`

   Depending of which version you installed, it should be a symlink to `docker-compose.local.yml` or `docker-compose.server.yml`.  
   Add this `- ./.vols/db9.5:/var/lib/postgresql/data/` below `- ./.vols/db:/srv/db`. It should look like this.
   
   ```
       - ./.vols/db:/srv/db
       - ./.vols/db9.5:/var/lib/postgresql/data/
   ```
   
3. Run `postgres` container
   
	```
	docker-compose run --rm postgres bash
	```

	Update apt-get
	
	```
	apt-get update  
	apt-cache policy postgresql-9.5-postgis-2.5
	apt-cache policy postgis
	```
	
	_Use the PostGIS version as a variable for later purpose_
		
	```
	POSTGIS_VERSION=$(apt-cache policy postgresql-9.5-postgis-2.5|grep Candidate:|awk '{print $2}')
	```

4. Install PostgreSQL 9.5

	```
	apt-get install -y --no-install-recommends postgresql-9.5-postgis-2.5=${POSTGIS_VERSION} postgresql-9.5-postgis-2.5-scripts=${POSTGIS_VERSION} postgis postgresql-contrib-9.5
	apt-get upgrade
	```

5. Init DB

	```
	chown -R postgres:postgres /var/lib/postgresql/data/
	su - postgres -c '/usr/lib/postgresql/9.5/bin/initdb --encoding=utf8 --locale=en_US.utf-8 -D /var/lib/postgresql/data/'
	```
	Results should look like this:
	
	> Success. You can now start the database server using:  
	>      /usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ -l logfile start

6. Start PostgreSQL 9.5 to ensure database has been initialized successfully

	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ start'
	```
	> ...  
	> LOG:  database system is ready to accept connections
	
	Press `enter` to go back to prompt.


7. Stop the server

	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ stop -m fast'
	```
	
	> ...  
	> server stopped
	
	
8. Upgrade Postgres 9.4
	
	```
	apt-cache policy postgresql-9.4-postgis-2.5
	apt-get install -y --no-install-recommends postgresql-9.4-postgis-2.5=${POSTGIS_VERSION} postgresql-9.4-postgis-2.5-scripts=${POSTGIS_VERSION}
	apt-get upgrade
	```
	
9. Start PostgreSQL 9.4
	
	```
	su - postgres -c '/usr/lib/postgresql/9.4/bin/pg_ctl -D /srv/db/ start'
	```
	Press `enter` to go back to prompt.
	```
	su - postgres -c '/usr/lib/postgresql/9.4/bin/psql'
	```
	
10. Upgrade PostGIS extension

    You may see some warnings `WARNING:  'postgis.backend' is already set and cannot be changed until you reconnect`. That's ok, you can keep going ahead.
	
	 ```
	 \c postgres;
	 CREATE EXTENSION IF NOT EXISTS postgis;
	 ALTER EXTENSION postgis UPDATE TO '2.5.0';
	 CREATE EXTENSION IF NOT EXISTS postgis_topology;
	 ALTER EXTENSION postgis_topology UPDATE TO '2.5.0';
	 CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
	 CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
	 ALTER EXTENSION postgis_tiger_geocoder UPDATE TO '2.5.0';
	
	 CREATE DATABASE template_postgis;
	 UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';
	
	 \c template_postgis;
	 CREATE EXTENSION IF NOT EXISTS postgis;
	 CREATE EXTENSION IF NOT EXISTS postgis_topology;
	 CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
	 CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
	
	 \c kobotoolbox;
	 ALTER EXTENSION postgis UPDATE TO '2.5.0';
	 ALTER EXTENSION postgis_topology UPDATE TO '2.5.0';
	 CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
	 CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
	 \q
	
	 su - postgres -c '/usr/lib/postgresql/9.4/bin/pg_ctl -D /srv/db/ stop -m fast'
	 ```
	
11. Check everything is ok
	
	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_upgrade --check --old-datadir=/srv/db/ --new-datadir=/var/lib/postgresql/data/ --old-bindir=/usr/lib/postgresql/9.4/bin --new-bindir=/usr/lib/postgresql/9.5/bin'
	```
	Results should look like this:
	
	> Performing Consistency Checks
	>  -----------------------------
	> Checking cluster versions                                   ok  
	> Checking database user is the install user                  ok  
	> Checking database connection settings                       ok  
	> Checking for prepared transactions                          ok  
	> Checking for reg* system OID user data types                ok  
	> Checking for contrib/isn with bigint-passing mismatch       ok  
	> Checking for presence of required libraries                 ok  
	> Checking database user is the install user                  ok  
	> Checking for prepared transactions                          ok  

	> \*Clusters are compatible\*
		
12. Upgrade databases
	
	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_upgrade --old-datadir=/srv/db/ --new-datadir=/var/lib/postgresql/data/ --old-bindir=/usr/lib/postgresql/9.4/bin --new-bindir=/usr/lib/postgresql/9.5/bin'
	```
    
    Results should like this:
    > Upgrade Complete  
    >  ---------------  
    > Optimizer statistics are not transferred by pg\_upgrade so,  
    > once you start the new server, consider running:  
    > ./analyze\_new\_cluster.sh

13. Prepare container to new version

    New version of `kobo-docker` creates `kobotoolbox` database with PostGIS extension at first run.  
    To avoid trying to this at each subsequent start, a file is created with date of first run.  
    We need to add this file because extensions have been installed during this migration.
    
    ```
    echo $(date) > /var/lib/postgresql/data/kobo_first_run
    echo "listen_addresses = '*'" >> /var/lib/postgresql/data/postgresql.conf
    echo "host    all             all             10.0.0.0/8            trust" >> /var/lib/postgresql/data/pg_hba.conf
    echo "host    all             all             172.0.0.0/8            trust" >> /var/lib/postgresql/data/pg_hba.conf
    echo "host    all             all             192.0.0.0/8            trust" >> /var/lib/postgresql/data/pg_hba.conf
    ```
    
    You can now quit the container with command `exit` and run new version of `PostgreSQL` container.

14. Edit composer file `docker-compose.yml` again

    The image used in old version of `kobo-docker` is `kobotoolbox/postgres:latest`.
    
    ```
    postgres:
        image: kobotoolbox/postgres:latest
    ```
    
    Change it to `mdillon/postgis:9.5` and comment `10_init_postgres.bash` script.
    
    ```
    postgres:
        image: mdillon/postgis:9.5
        ...
        volumes:
          ...
          #- ./base_images/postgres/init_postgres.bash:/etc/my_init.d/10_init_postgres.bash:ro

    ```

15. Test if upgrade is successful

    Start your containers as usual.
    
    ```
    docker-compose up
    ```
    
    Log into one user account

16. Clean up
    
    If everything is ok, you can now deleted data from `PostgreSQL 9.4`
    Stop `postgres` container.
    
    ```
    docker-compose stop postgres
    sudo rm -rf .vols/db
    sudo mv .vols/db9.5 .vols/db
    ```
    
    Done!   

### MongoDB

**Upgrading Mongo is easy and only implies a couple of stop/start.**
    
1. Upgrade to 3.0

    Stop the container: `docker-compose stop mongo`  
    We need to change few lines in `docker-compose.yml`

    - Change image to `mongo:3.0`
    - Change `srv` to `data`
    
    ```
    mongo:
      image: mongo:3.0
      environment:
        - MONGO_DATA=/data/db
      ...
      volumes:
        - ./.vols/mongo:/data/db
    ```
    Then start the container: `docker-compose start mongo`
    
1. Upgrade to 3.2

    Stop the container: `docker-compose stop mongo`  
    We only need to change the image in `docker-compose.yml`

    - Change image to `mongo:3.2`
   
    ```
    mongo:
      image: mongo:3.2
      ...
    ```
    Then start the container: `docker-compose start mongo`
    
1. Upgrade to 3.4

    Stop the container: `docker-compose stop mongo`  
    We only need to change the image in `docker-compose.yml`

    - Change image to `mongo:3.4`
   
    ```
    mongo:
      image: mongo:3.4
      ...
    ```
    Then start the container: `docker-compose start mongo`

    Done!
    
    
You can now use latest version `kobo-docker` (or use `kobo-install`)


## Load balancing and redundancy 

1. Load balancing
    `kobo-docker` has two different composer files. One for `frontend` and one for `backend`. 
    
    1. `frontend`: 
        - `NGinX`
        - `KoBoCat`
        - `KPI`
        - `Enketo Express`
    
    2. `backend`:
        - `PostgreSQL`
        - `MongoDB`
        - `RabbitMQ`
        - `redis`
    
    Docker-compose for `frontend` can be start on its own server, same thing for `backend`. Users can start as many `frontend` servers they want. A load balancer can spread the traffic between `frontend` servers. 
    `kobo-docker` used to use docker links to communicate but now uses (private) domain names between `frontend` and `backend`. 
    It's fully customizable in configuration files. Once again `kobo-install` does simplify the job by creating the configuration files for you.

2. Redundancy
    `Backend` containers not redundant yet. Only `PostgreSQL` can be configured in `Master/Slave` mode where `Slave` is a real-time read-only replica. 
       
This is a diagram shows how `kobo-docker` can be used for a load-balanced/(almost) redundant solution.
       
_NB: The diagram is based on AWS infrastructure, but it's not required to host your environment there._

![aws diagram](./doc/aws-diagram.svg)


## Warning
If you started running KoBo Toolbox using a version of `kobo-docker` from before to [2016.10.13](https://github.com/kobotoolbox/kobo-docker/commit/316b1464c86e2c447ca88c10d383662b4f2e4ac6), actions that recreate the `kobocat` container (including `docker-compose up ...` under some circumstances) will result in losing access to user media files (e.g. responses to photo questions). Safely stored media files can be found in `kobo-docker/.vols/kobocat_media_uploads/`.

Files that were not safely stored can be found inside Docker volumes as well as in your current and any previous `kobocat` containers. One quick way of finding these is directly searching the Docker root directory. The root directory can be found by running `docker info` and looking for the "Docker Root Dir" entry (not to be confused with the storage driver's plain "Root Dir").

Once this is noted, you can `docker-compose stop` and search for potentially-missed media attachment directories with something like `sudo find ${YOUR_DOCKER_ROOT_DIR}/ -name attachments`. These attachment directories will be of the format `.../${SOME_KOBO_USER}/attachments` and you will want to back up each entire KoBo user's directory (the parent of the `attachments` directory) for safe keeping, then move/merge them under `.vols/kobocat_media_uploads/`, creating that directory if it doesn't exist and taking care not to overwrite any newer files present there if it does exist. Once this is done, clear out the old container and any attached volumes with `docker-compose rm -v kobocat`, then `git pull` the latest `kobo-docker` code, `docker-compose pull` the latest images for `kobocat` and the rest, and your media files will be safely stored from there on.


## Backups

Automatic, periodic backups of KoBoCAT media, MongoDB, PostgreSQL and Redis can be individually enabled by uncommenting (and optionally customizing) the *_BACKUP\_SCHEDULE variables in your envfiles. 

 - `deployments/envfiles/databases.txt` (MongoDB, PostgreSQL, Redis)
 - `deployments/envfiles/kobocat.txt` (KoBoCat media)

When enabled, timestamped backups will be placed in backups/kobocat, backups/mongo, backups/postgres and backups/redis respectively.

#### AWS
If `AWS` credentials and `AWS S3` backup bucket name are provided, the backups are created directly on `S3`.

Backups **on disk** can also be manually triggered when kobo-docker is running by executing the the following commands:

```
docker exec -it kobodocker_kobocat_1 /srv/src/kobocat/docker/backup_media.bash
docker exec -it kobodocker_mongo_1 /bin/bash /kobo-docker-scripts/backup-to-disk.bash
docker exec -it -e PGUSER=kobo kobodocker_postgres_1 /bin/bash /kobo-docker-scripts/backup-to-disk.bash
docker exec -it kobodocker_redis_main_1 /bin/bash /kobo-docker-scripts/backup-to-disk.bash
```

#### Restore
 Within containers.

 - MongoDB: `mongorestore --archive=<path/to/mongo.backup.gz> --gzip`
 - PostgreSQL: `pg_restore -U kobo -d kobotoolbox -c "<path/to/postgres.pg_dump>"`
 - Redis: `gunzip <path/to/redis.rdb.gz> && mv <path/to/extracted_redis.rdb> /data/enketo-main.rdb` 

## Maintenance mode

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

There are 3 variables that can be customized in `docker-compose.maintenance.yml`

- `ETA` e.g. `2 hours`
- `DATE_STR` e.g. `Monday, November 26 at 02:00 GMT`
- `DATE_ISO` e.g. `20181126T02`

## Troubleshooting

### Basic troubleshooting
You can confirm that your containers are running with `docker ps`. 
To inspect the log output from:
 
 - the frontend containers, execute `docker-compose -f docker-compose.frontend.yml [-f docker-compose.frontend.override.yml] logs -f`
 - the master backend containers, execute `docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] logs -f`
 - the slaved backend container, execute `docker-compose -f docker-compose.backend.slave.yml [-f docker-compose.backend.slave.override.yml] logs -f`
   
For a specific container use e.g. `docker-compose -f docker-compose.backend.master.yml [-f docker-compose.backend.master.override.yml] logs -f redis_main`.

`override` YML files are optionals but strongly recommended.
If you are using `kobo-install`, it will create those files for you.  

The documentation for Docker can be found at https://docs.docker.com.

### Django debugging
Developers can use [PyDev](http://www.pydev.org/)'s [remote, graphical Python debugger](http://www.pydev.org/manual_adv_remote_debugger.html) to debug Python/Django code. To enable for the `kpi` container:

1. Specify the mapping(s) between target Python source/library paths on the debugging machine to the locations of those files/directories inside the container by customizing and uncommenting the `KPI_PATH_FROM_ECLIPSE_TO_PYTHON_PAIRS` variable in [`envfiles/kpi.txt`](./envfiles/kpi.txt).
2. Share the source directory of the PyDev remote debugger plugin into the container by customizing (taking care to note the actual location of the version-numbered directory) and uncommenting the relevant `volumes` entry in your `docker-compose.yml`.
3. To ensure PyDev shows you the same version of the code as is being run in the container, share your live version of any target Python source/library files/directories into the container by customizing and uncommenting the relevant `volumes` entry in your `docker-compose.yml`.
4. Start the PyDev remote debugger server and ensure that no firewall or other settings will prevent the containers from connecting to your debugging machine at the reported port.
5. Breakpoints can be inserted with e.g. `import pydevd; pydevd.settrace('${DEBUGGING_MACHINE_IP}')`.

Remote debugging in the `kobocat` container can be accomplished in a similar manner.


## Redis performance
Please take a look at https://www.techandme.se/performance-tips-for-redis-cache-server/
to get rid of Warning message when starting redis containers    




