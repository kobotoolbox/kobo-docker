## Upgrading from an old version of kobo-docker (before March 2019)

Current versions of kobo-docker require PostgreSQL 9.5 and MongoDB 3.4.
Additionally, **Redis is now the Celery broker**, and RabbitMQ is no longer
needed.

If you are running a version of kobo-docker that was last updated prior to
March 2019
(i.e. commit [`5c2ef02`](https://github.com/kobotoolbox/kobo-docker/commit/5c2ef0273339bee5c374830f72e52945947042a8) or older),
you need to upgrade your databases prior to using the current version of
kobo-docker (this repository) or
[kobo-install](https://github.com/kobotoolbox/kobo-install).

This is a step-by-step procedure to upgrade PostgreSQL and MongoDB.

### PostgreSQL

**Be sure to have enough space left on the host filesystem before upgrading.**
Check the size of the PostgreSQL database in  `.vols/db`, e.g. with
`sudo du -hs .vols/db`, and ensure you have _more_ than this amount of space
free.


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

	_Store the PostGIS version in a variable to use later_

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

    > ```
	> Success. You can now start the database server using:
	>      /usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ -l logfile start
    > ```

6. Start PostgreSQL 9.5 to ensure database has been initialized successfully

	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ start'
	```
    > ```
	> ...
	> LOG:  database system is ready to accept connections
    > ```

	Press `enter` to go back to prompt.


7. Stop the server

	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ stop -m fast'
	```

    > ```
	> ...
	> server stopped
    > ```


8. Upgrade Postgres 9.4

	```
	apt-cache policy postgresql-9.4-postgis-2.5
	POSTGIS_VERSION=$(apt-cache policy postgresql-9.4-postgis-2.5|grep Candidate:|awk '{print $2}')
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
	 ALTER EXTENSION postgis UPDATE TO '2.5.3';
	 CREATE EXTENSION IF NOT EXISTS postgis_topology;
	 ALTER EXTENSION postgis_topology UPDATE TO '2.5.3';
	 CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
	 CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
	 ALTER EXTENSION postgis_tiger_geocoder UPDATE TO '2.5.3';

	 CREATE DATABASE template_postgis;
	 UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';

	 \c template_postgis;
	 CREATE EXTENSION IF NOT EXISTS postgis;
	 CREATE EXTENSION IF NOT EXISTS postgis_topology;
	 CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
	 CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;

	 \c kobotoolbox;
	 ALTER EXTENSION postgis UPDATE TO '2.5.3';
	 ALTER EXTENSION postgis_topology UPDATE TO '2.5.3';
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

    > ```
	> Performing Consistency Checks
	> -----------------------------
	> Checking cluster versions                                   ok
	> Checking database user is the install user                  ok
	> Checking database connection settings                       ok
	> Checking for prepared transactions                          ok
	> Checking for reg* system OID user data types                ok
	> Checking for contrib/isn with bigint-passing mismatch       ok
	> Checking for presence of required libraries                 ok
	> Checking database user is the install user                  ok
	> Checking for prepared transactions                          ok
    >
	> *Clusters are compatible*
    > ```

12. Upgrade databases

	```
	su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_upgrade --old-datadir=/srv/db/ --new-datadir=/var/lib/postgresql/data/ --old-bindir=/usr/lib/postgresql/9.4/bin --new-bindir=/usr/lib/postgresql/9.5/bin'
	```

    Results should like this:

    > ```
    > Upgrade Complete
    > ---------------
    > Optimizer statistics are not transferred by pg_upgrade so,
    > once you start the new server, consider running:
    > ./analyze_new_cluster.sh
    > ```

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

    Change it to `postgis/postgis:9.5-2.5` and comment `10_init_postgres.bash` script.

    ```
    postgres:
        image: postgis/postgis:9.5-2.5
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

    If everything is ok, you can now delete data from `PostgreSQL 9.4`
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
    Then start the container: `docker-compose up --force-recreate mongo`

1. Upgrade to 3.2

    Stop the container: `docker-compose stop mongo`
    We only need to change the image in `docker-compose.yml`

    - Change image to `mongo:3.2`

    ```
    mongo:
      image: mongo:3.2
      ...
    ```
    Then start the container: `docker-compose up --force-recreate mongo`

1. Upgrade to 3.4

    Stop the container: `docker-compose stop mongo`
    We only need to change the image in `docker-compose.yml`

    - Change image to `mongo:3.4`

    ```
    mongo:
      image: mongo:3.4
      ...
    ```
    Then start the container: `docker-compose up --force-recreate mongo`

    Done!


You can now use latest version of kobo-docker (or use kobo-install)
