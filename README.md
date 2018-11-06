## kobo-docker

`kobo-docker` is used to run a copy of the [KoBo Toolbox](http://www.kobotoolbox.org) survey data collection platform on a machine of your choosing. It relies on [Docker](https://docker.com) to separate the different parts of KoBo into different containers (which can be thought of as lighter-weight virtual machines) and [Docker Compose](https://docs.docker.com/compose/) to configure, run, and connect those containers. 
Below is a diagram (made with [Lucidchart](lucidchart.com)) of the containers that make up a running `kobo-docker` system and their connections. 

![Container diagram](./doc/Container_diagram.png)


## Setup procedure:

This procedure has been simplified by using [`kobo-install`](https://github.com/kobotoolbox/kobo-install ""). 
Please use it to install `kobo-docker`.   
Already have an existing installation? Please see below.

## Upgrading from an old version of `kobo-docker`
Latest version of `kobo-docker` use `PostgreSQL 9.5` and `MongoDB 3.4`. 

If you already run an older version of `kobo-docker`, you need to upgrade to these version first before
using this version (or `kobo-install`).
This is a step-by-step procedure to upgrade `PostgreSQL` and `MongoDB` containers

### PostgreSQL
**To upgrade to PostgresSQL 9.5, you will need to have twice the space of the database size.**  
**Be sure to have enough space left on the host filesystem before upgrading.**


1. Edit composer file
   Add this `- ./.vols/db9.5:/var/lib/postgresql/data/` below `- ./.vols/db:/srv/db`. It should look like this.
   
   ```
       - ./.vols/db:/srv/db
       - ./.vols/db9.5:/var/lib/postgresql/data/
   ```
1. Stop the containers
   
   ```
   docker-compose stop
   ```
   
1. Run `postgres` container.
   
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

2. Install PostgreSQL 9.5

	```
	apt-get install -y --no-install-recommends postgresql-9.5-postgis-2.5=${POSTGIS_VERSION} postgresql-9.5-postgis-2.5-scripts=${POSTGIS_VERSION} postgis postgresql-contrib-9.5
	apt-get upgrade
	```

3. Init DB

	```
	chown -R postgres:postgres /var/lib/postgresql/data/
	su - postgres -c '/usr/lib/postgresql/9.5/bin/initdb --encoding=utf8 --locale=en_US.utf-8 -D /var/lib/postgresql/data/'
	```

4. Start PostgreSQL 9.5 to ensure init went successfully

	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ start'
	```
	> ...  
	> LOG:  database system is ready to accept connections
	
	Press `enter` to go back to prompt.


5. Stop the server

	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ stop -m fast'
	```
	
	> ...  
	> server stopped
	
	
6. Upgrade Postgres 9.4
	
	```
	apt-cache policy postgresql-9.4-postgis-2.5
	apt-get install -y --no-install-recommends postgresql-9.4-postgis-2.5=${POSTGIS_VERSION} postgresql-9.4-postgis-2.5-scripts=${POSTGIS_VERSION}
	apt-get upgrade
	```
	
7. Start PostgreSQL 9.4
	
	```
	su - postgres -c '/usr/lib/postgresql/9.4/bin/pg_ctl -D /srv/db/ start'
	```
	Press `enter` to go back to prompt.
	```
	su - postgres -c '/usr/lib/postgresql/9.4/bin/psql'
	```
	
8. Upgrade PostGIS extension
	
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
	
9. Check everything is ok
	
	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_upgrade --check --old-datadir=/srv/db/ --new-datadir=/var/lib/postgresql/data/ --old-bindir=/usr/lib/postgresql/9.4/bin --new-bindir=/usr/lib/postgresql/9.5/bin'
	```
	
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
		
10. Upgrade is check returns `Clusters are compatible`
	
	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_upgrade --old-datadir=/srv/db/ --new-datadir=/var/lib/postgresql/data/ --old-bindir=/usr/lib/postgresql/9.4/bin --new-bindir=/usr/lib/postgresql/9.5/bin'
	```

11. Edit 
    
12. Test if data is there.
    Start your containers as usual.
    
    ```
    echo $(date) > /var/lib/postgresql/data/kobo_first_run
    ```
    ```
    docker-compose up
    ```

11. Clean up
    
    ```
    /var/lib/postgresql/analyze_new_cluster.sh
    /var/lib/postgresql/delete_old_cluster.sh
    ```



## Load balancing and redundancy 

The main goal of this branch is to make applications containers aka `frontends` run on one host (`KoBoCat`, `KPI`, `Enketo Express`) and make databases containers aka `backends` (`PostgreSQL`, `MongoDB`, `RabbitMQ`, `redis`) run on another.

In `kobo-docker` master branch, each container communicate to each other through docker internal network and `link` property. Even if `KoBoCat`, `KPI`, `Enketo Express` on the same instance still communicate the same way, they now use domain names (or IP addresses) to communicate with `backends`. It allows `frontends` to be behind a load-balancer and to be redundant. 

### To-Do
`Backends` are not redundant yet except `PostgreSQL` which is configured in Master/Slave mode. Slave is a real-time read-only replica.

Below is another diagram (made with [Lucidchart](lucidchart.com)) of the containers that make up a running `kobo-docker` redundant system and their connections. 
   
_NB: The diagram is based on AWS infrastructure, but it's not required to host your environment there._

![aws diagram](./doc/aws-diagram.svg)


## Warning
If you started running KoBo Toolbox using a version of `kobo-docker` from before to [2016.10.13](https://github.com/kobotoolbox/kobo-docker/commit/316b1464c86e2c447ca88c10d383662b4f2e4ac6), actions that recreate the `kobocat` container (including `docker-compose up ...` under some circumstances) will result in losing access to user media files (e.g. responses to photo questions). Safely stored media files can be found in `kobo-docker/.vols/kobocat_media_uploads/`.

Files that were not safely stored can be found inside Docker volumes as well as in your current and any previous `kobocat` containers. One quick way of finding these is directly searching the Docker root directory. The root directory can be found by running `docker info` and looking for the "Docker Root Dir" entry (not to be confused with the storage driver's plain "Root Dir").

Once this is noted, you can `docker-compose stop` and search for potentially-missed media attachment directories with something like `sudo find ${YOUR_DOCKER_ROOT_DIR}/ -name attachments`. These attachment directories will be of the format `.../${SOME_KOBO_USER}/attachments` and you will want to back up each entire KoBo user's directory (the parent of the `attachments` directory) for safe keeping, then move/merge them under `.vols/kobocat_media_uploads/`, creating that directory if it doesn't exist and taking care not to overwrite any newer files present there if it does exist. Once this is done, clear out the old container and any attached volumes with `docker-compose rm -v kobocat`, then `git pull` the latest `kobo-docker` code, `docker-compose pull` the latest images for `kobocat` and the rest, and your media files will be safely stored from there on.


## Backups
**POSTGRES AUTOMATIC BACKUP IS CURRENTLY UNAVAILABLE**  

Automatic, periodic backups of KoBoCAT media, MongoDB, and Postgres can be individually enabled by uncommenting (and optionally customizing) the `*_BACKUP_SCHEDULE` variables in your `envfile`. When enabled, timestamped backups will be placed in `backups/kobocat`, `backups/mongo`, and `backups/postgres`, respectively. Redis backups are currently not generated, but the `redis_main` DB file is updated every 5 minutes and can always be found in `.vols/redis_main_data/`.

Backups can also be manually triggered when `kobo-docker` is running by executing the the following commands:
```
docker exec -it kobodocker_kobocat_1 /srv/src/kobocat/docker/backup_media.bash
docker exec -it kobodocker_mongo_1 /srv/backup_mongo.bash
docker exec -it kobodocker_postgres_1 /srv/backup_postgres.bash
```

## Troubleshooting

### Basic troubleshooting
You can confirm that your containers are running with `docker ps`. To inspect the log output from the containers, execute `docker-compose logs -f` or for a specific container use e.g. `docker-compose logs -f redis_main`.

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




