## Upgrading from an old version of kobo-docker (before November 17, 2022)

Current versions of kobo-docker (release [`2.022.44`](https://github.com/kobotoolbox/kobo-docker/releases/tag/2.022.44) and later) require PostgreSQL 14, MongoDB 5, and Redis 6.


If you are running a version of kobo-docker that was last updated prior to
November 17, 2022 (i.e. older than release [`2.022.44`](https://github.com/kobotoolbox/kobo-docker/releases/tag/2.022.44)),
you need to upgrade your databases before using the current version of
kobo-docker (this repository) or
[kobo-install](https://github.com/kobotoolbox/kobo-install).

This is a step-by-step procedure to upgrade PostgreSQL and MongoDB.

**This procedure has been tested on x86 architecture only.**

### PostgreSQL

**Be sure to have enough space left on the host filesystem before upgrading.**
Check the size of the PostgreSQL database in  `.vols/db`, e.g. with
`sudo du -hs .vols/db`, and ensure you have _more_ than this amount of space
free.

For this tutorial, we are using kobo-install to run docker-compose commands.
If you do not use kobo-install, please replace `python3 run.py -cb` with `docker-compose -f docker-compose.primary.backend.template.yml -f docker-compose.primary.backend.yml [-f docker-compose.primary.backend.override.yml] [-f docker-compose.primary.backend.custom.yml]`

1. Stop the containers

    ```shell
    user@computer:kobo-install$ python3 run.py --stop
    ```

1. Edit composer file `docker-compose.primary.backend.template.yml`

   - Temporarily, comment `postgis/postgis:14-3.2` to use PostgreSQL 9.5 with PostGIS 2.5  
   - Add `- ./.vols/db14:/var/lib/postgresql/data14` below `- ./.vols/db:/var/lib/postgresql/data` as in this diff below:

    ```diff
    @@ -5,7 +5,8 @@ version: '2.2'
    
     services:
       postgres:
    -    image: postgis/postgis:14-3.2
    +    # image: postgis/postgis:14-3.2
    +    image: postgis/postgis:9.5-2.5
         hostname: postgres
         env_file:
           - ../kobo-env/envfile.txt
    @@ -13,6 +14,7 @@ services:
           - ../kobo-env/envfiles/aws.txt
         volumes:
           - ./.vols/db:/var/lib/postgresql/data
    +      - ./.vols/db14:/var/lib/postgresql/data14
    ```
   

   It should look like this:

    ```
    # image: postgis/postgis:14-3.2
    image: postgis/postgis:9.5-2.5
    hostname: postgres
    env_file:
      - ../kobo-env/envfile.txt
      - ../kobo-env/envfiles/databases.txt
      - ../kobo-env/envfiles/aws.txt
    volumes:
      - ./.vols/db:/var/lib/postgresql/data
      - ./.vols/db14:/var/lib/postgresql/data14
    ```

1. Run a one-off `PostgreSQL` container

    ```shell
    user@computer:kobo-install$ python3 run.py -cb run --rm postgres bash  
    ```
    
1. Install PostgreSQL 14

    ```shell
    root@postgres:/# rm -rf /etc/apt/sources.list.d/pgdg.list && \
        apt-get update && \
        apt-get install apt-transport-https ca-certificates
    ```    
    
    ```shell
    root@postgres:/# echo "deb https://apt-archive.postgresql.org/pub/repos/apt stretch-pgdg-archive main" >> /etc/apt/sources.list && \
        echo "deb-src https://apt-archive.postgresql.org/pub/repos/apt stretch-pgdg-archive main" >> /etc/apt/sources.list
    ```

    ```shell
    root@postgres:/# apt-get update && \
        apt-cache policy postgresql-14-postgis-3 && \
        apt-cache policy postgis
    ```

    _Store the PostGIS version in a variable to use later_
    
    ```shell
    root@postgres:/# POSTGIS_VERSION_14=$(apt-cache policy postgresql-14-postgis-3|grep Candidate:|awk '{print $2}') && \
        apt-get install -y --no-install-recommends postgresql-14-postgis-3=${POSTGIS_VERSION_14} postgresql-14-postgis-3-scripts=${POSTGIS_VERSION_14} postgis postgresql-contrib-14 && \
        apt-get upgrade
    ```

    _Notes: You may receive a (long) warning that PostgreSQL 9.5 is obsolete: ignore it and continue. When asked about configuration files, choose `install the package maintainer's version`._

1. Initialize the database

    ```shell
    root@postgres:/# chown -R postgres:postgres /var/lib/postgresql/data14/ && \
        su - postgres -c "/usr/lib/postgresql/14/bin/initdb -U $POSTGRES_USER --encoding=utf8 --locale=en_US.utf-8 -D /var/lib/postgresql/data14/"
    ```
    **It is important to initialize the PostgreSQL 14 cluster with the same username used to initialize PostgreSQL 9.5.**
    Ensure that `$POSTGRES_USER` equals that username. If it is not the case, replace `$POSTGRES_USER` with the correct username (in all following instructions).

    Results should look like this:

    > ```
    > Success. You can now start the database server using:
    >      /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data14/ -l logfile start
    > ```

1. Start PostgreSQL 14 to ensure database has been initialized successfully

    ```shell
    root@postgres:/# su - postgres -c '/usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data14/ start'
    ```
    > ```
    > ...
    > LOG:  database system is ready to accept connections
    > ```

    Press `enter` to go back to prompt.

1. Stop the server

    ```
    root@postgres:/# su - postgres -c '/usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data14/ stop -m fast'
    ```

    > ```
    > ...
    > server stopped
    > ```


1. Upgrade PostgreSQL 9.5

    ```shell
    root@postgres:/# apt-cache policy postgresql-9.5-postgis-3 && \
        POSTGIS_VERSION_9_5=$(apt-cache policy postgresql-9.5-postgis-3|grep Candidate:|awk '{print $2}') && \
        apt-get install -y --no-install-recommends postgresql-9.5-postgis-3=${POSTGIS_VERSION_9_5} postgresql-9.5-postgis-3-scripts=${POSTGIS_VERSION_9_5} && \
        apt-get upgrade
    ```
 
1. Start PostgreSQL 9.5

    ```shell
    root@postgres:/# su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ start'
    ```
    
    Press `enter` to go back to prompt and enter `psql` cli client:
    
    ```shell
    root@postgres:/# /usr/lib/postgresql/9.5/bin/psql -U $POSTGRES_USER -d postgres
    ```

1. Upgrade PostGIS extension

    You may see some warnings `WARNING:  'postgis.backend' is already set and cannot be changed until you reconnect`. That's ok, you can keep going ahead.

    Depending on your kobo-docker environment, databases may have other names.  
    You may need to adapt the snippet below to your current configuration.
    
    _Notes: You may need to copy lines below one by one because sometimes copying the whole block does not work as expected (e.g.: error like `invalid integer value "postgis" for connection option "port"`)._
    
    ```
    CREATE EXTENSION IF NOT EXISTS postgis;
    ALTER EXTENSION postgis UPDATE;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    ALTER EXTENSION postgis_topology UPDATE;
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
    CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
    
    \c template_postgis;
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
    
    \c koboform;
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
     
    \c kobocat;
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
     
    \c kobo;
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
     
    \q
    ```
    
1. Restore `postgres` role

    For installations created after March 2019, `postgres` role may not exist but is needed for database clusters.

    ```shell
    root@postgres:/# /usr/lib/postgresql/9.5/bin/psql -U "$POSTGRES_USER" -d postgres -q -c "CREATE USER postgres WITH SUPERUSER CREATEDB CREATEROLE REPLICATION BYPASSRLS ENCRYPTED PASSWORD '$POSTGRES_PASSWORD';"
    ```
    
    _If user already exists, you should see `ERROR:  role "postgres" already exists`._

1. Stop PostgreSQL 9.5 

    ```shell
    root@postgres:/# su - postgres -c '/usr/lib/postgresql/9.5/bin/pg_ctl -D /var/lib/postgresql/data/ stop -m fast'
    ```
    
1. Check everything is ok

    ```shell
    root@postgres:/# su - postgres -c "/usr/lib/postgresql/14/bin/pg_upgrade \
        --check --old-datadir=/var/lib/postgresql/data/ \
        --new-datadir=/var/lib/postgresql/data14/ \
        --old-bindir=/usr/lib/postgresql/9.5/bin \
        --new-bindir=/usr/lib/postgresql/14/bin -U $POSTGRES_USER"
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

1. Upgrade databases

    ```shell
    root@postgres:/# su - postgres -c "/usr/lib/postgresql/14/bin/pg_upgrade \
        --old-datadir=/var/lib/postgresql/data/ \
        --new-datadir=/var/lib/postgresql/data14/ \
        --old-bindir=/usr/lib/postgresql/9.5/bin \
        --new-bindir=/usr/lib/postgresql/14/bin -U $POSTGRES_USER"
    ```

    Results should look like this:

    > ```
    > Upgrade Complete
    > ---------------
    > ```
    
    You can exit the one-off container
    
    ```shell
    root@postgres:/# exit
    ```

1. Edit composer file `docker-compose.backend.template.yml` again

    Locate

    ```
    postgres:
        image: postgis/postgis:9.5-2.5
    ```

    Change it to `postgis/postgis:14-3.2` and change volume `./.vols/db14` to point to `/var/lib/postgresql/data`.

    ```
    postgres:
        image: postgis/postgis:14-3.2
        ...
        volumes:
          # - ./.vols/db:/var/lib/postgresql/data
          - ./.vols/db14:/var/lib/postgresql/data
          ...
    ```

1. Update PostGIS extensions once again

    Start again a one-off `PostgreSQL` container (see Point 3 for commands)

    Start the server
    
    ```shell
    root@postgres:/# su - postgres -c '/usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data/ start'
    ```
    
    Press `enter` to go back to prompt and enter `psql` cli client:
    
    ```shell
    root@postgres:/# /usr/lib/postgresql/14/bin/psql -U $POSTGRES_USER -d postgres
    ```
    
    Once again, you may need to adapt the snippet below according your current configuration.
    
    _Notes: You may need to copy lines below one by one because sometimes copying the whole block does not work as expected._

    ```
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
    
    \c template_postgis;
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
    
    \c koboform;
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
     
    \c kobocat;
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
     
    \c kobo;
    ALTER EXTENSION postgis UPDATE;
    ALTER EXTENSION postgis_topology UPDATE;
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
    SELECT postgis_extensions_upgrade();
     
    \q
    ```
    
1. Prepare container for new version

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

### MongoDB

**Upgrading Mongo is easy and only requires several stops and starts** — provided you are already using the `WiredTiger` engine.

Please note that MongoDB [recommends using an XFS partition](https://www.mongodb.com/docs/manual/administration/production-notes/#kernel-and-file-systems) to store its data.

> With the WiredTiger storage engine, using XFS is strongly recommended for data bearing nodes to avoid performance issues that may occur when using EXT4 with WiredTiger.



1. Upgrade to `WiredTiger` engine if MongoDB is not already using it.

    To validate if your MongoDB instance is using the correct engine, run this command.
    
    ```shell
    user@computer:kobo-install$ python3 run.py -cb exec mongo bash
    root@mongo:/# mongo -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" admin
    > db.serverStatus().storageEngine
    ```
       
    You should get something similar to: 
       
    ```
    {
       "name" : "wiredTiger" 
       ...
    }
    ```
       
    If it is the case, you can go to next step **Update to 3.6**. Otherwise, please follow the steps below to upgrade to `WiredTiger`. 
    
    You can use mongodump and mongorestore, but in some cases the engine is not updated to `WiredEngine`.
       
    In the steps below, we assume the XFS partition is mounted at `/mnt/data/` and kobo-install is installed in `/home/ubuntu`. Please adapt accordingly to your configuration. Moreover, ports `27017` and `28017` must be open locally.
       
    1. Create a temporary folder and docker-compose file
    
        ```shell
        user@computer:~$ mkdir mongo-replica && cd mongo-replica 
        ```
    
       1. Create a new docker compose file, i.e.: `docker-compose.yml`, to start a secondary MongoDB instance (i.e. a read replica)
        
        ```yml
        version: '2.2'
            
        services:
          mongo_secondary:
            image: mongo:3.4
            hostname: mongo_secondary
            environment:
              - MONGO_DATA=/data/db
              - KEY_FILE_SECRET=<base64-characters-only>
            env_file:
              - /home/ubuntu/kobo-env/envfile.txt
              - /home/ubuntu/kobo-env/envfiles/databases.txt
              - /home/ubuntu/kobo-env/envfiles/aws.txt
            volumes:
              - /mnt/mongo:/data/db
              - ./kobo:/kobo
            ports:
              - 28017:27017
            command: "bash /kobo/entrypoint.sh"
            extra_hosts:
              - mongo:<instance-ip>
        ```

        Change:
        
        - `<instance-ip>` to the current local ip of the server
        - `<base64-characters-only>` to random base64 characters long and secure string (see https://passwordsgenerator.net/)
        - `/home/ubuntu` to match your current location
        - `/mnt/mongo` to match your XFS mount

    1. Within the same folder, create another folder `kobo` and save the following content as `entrypoint.sh`
    
        ```bash
        #!/usr/bin/env bash
        # set -e
        
        echo "$KEY_FILE_SECRET" > /keyFile
        chmod 600 /keyFile
        chown mongodb:mongodb /keyFile
        exec docker-entrypoint.sh mongod --replSet replicaSet1 --keyFile /keyFile
        ```
    
    1. Start the read-replica 
    
        ```bash 
        user@computer:mongo-replica$ docker-compose up
        ```
    
        _Notes: Do not forget to run the command within a tmux/byobu session to not lose the connection to the server. Otherwise, use `-d` option to start the container_
    
    
    1. Modify current MongoDB settings
    
     - Edit `/home/ubuntu/kobo-docker/mongo/entrypoint.sh` and apply the diff below
        
        ```diff
        diff --git a/mongo/entrypoint.sh b/mongo/entrypoint.sh
        index 9d43502..b01d259 100644
        --- a/mongo/entrypoint.sh
        +++ b/mongo/entrypoint.sh
        @@ -17,4 +17,10 @@ bash $KOBO_DOCKER_SCRIPTS_DIR/post_startup.sh &
         echo "Launching official entrypoint..."
         # `exec` here is important to pass signals to the database server process;
         # without `exec`, the server will be terminated abruptly with SIGKILL (see #276)
        -exec docker-entrypoint.sh mongod
        +# exec docker-entrypoint.sh mongod
        +
        +
        +echo "$KEY_FILE_SECRET" > /keyFile
        +chmod 600 /keyFile
        +chown mongodb:mongodb /keyFile
        +exec docker-entrypoint.sh mongod --replSet replicaSet1 --keyFile /keyFile
        ```
    
     - Edit `/home/ubuntu/kobo-docker/docker-compose.backend.primary.override.yml`
        Add the section below to `mongo` service
    
        ```yml
        diff --git a/docker-compose.backend.primary.override.yml b/docker-compose.backend.primary.override.yml
        index bbc72eb..1e25f73 100644
        --- a/docker-compose.backend.primary.override.yml
        +++ b/docker-compose.backend.primary.override.yml
        @@ -18,6 +18,8 @@ services:
           mongo:
             ports:
               - 27017:27017
        +    environment:
        +      - KEY_FILE_SECRET=<same_key_as_replica_read>
             #networks:
             #  kobo-be-network:
             #    aliases:
        ```
    
    1. Restart primary MongoDB (without daemon mode to validate everything is running smoothly)
        
        ```bash
        user@computer:kobo-install$ ./run.py -cb up --force-recreate mongo
        ```
            
    1. Enter primary MongoDB container
    
        ```bash  
        user@computer:kobo-install$ ./run.py -cb exec mongo bash
        root@mongo:/$ mongo -u root -p "$MONGO_INITDB_ROOT_PASSWORD" admin
        ...
        > rs.initiate()
        > rs.add({"host":"<secondary_node_ip>:28017", "priority": 0.5})
        ```
        
        Change:
        - `<secondary_node_ip>` to current local ip of the server
        
    **Replication should start at this moment**
    
    1. Test whether replication is successful
    
        ```bash
        # Number of instances on primary node
        replicaSet1:PRIMARY> db.instances.count()
        10000
        
        # Number of instances on secondary node
        # Might need to first run rs.slaveOk() or rs.secondaryOk()
        replicaSet1:SECONDARY> db.instances.count()
        10000
        
        # id of last document on primary node
        replicaSet1:PRIMARY> db.instances.find().sort({"_id": -1}).limit(1)
        { "_id" : 1234567 ...
        
        # id of last document on secondary node
        replicaSet1:SECONDARY> db.instances.find().sort({"_id": -1}).limit(1)
        { "_id" : 1234567 ...
        
        # id of the first document on primary node
        replicaSet1:PRIMARY> db.instances.find().sort({"_id": 1}).limit(1)
        { "_id" : 1, ...
        
        # id of the secondary document on primary node
        replicaSet1:SECONDARY> db.instances.find().sort({"_id": 1}).limit(1)
        { "_id" : 1, ...
        
        ```
    
    
    1. Make MongoDB use new `/mnt/mongo`
    
        1. Stop MongoDB primary node
        
            ```
            user@computer:kobo-install$ ./run.py -cb stop mongo
            ```
        
        1. Stop read-replica 
        
            ```
            user@computer:mongo-replica$ docker-compose down
            ```
        
        1. Create a symlink of `/mnt/mongo` to `kobo-docker/.vols/mongo`
            
            ```
            user@computer:mongo-replica$ ln -s /mnt/mongo /home/ubukobo-docker/.vols/mongo
            ```
            
        1. Restart MongoDB in standalone (remove `--replSet replicaSet1 --keyFile /keyFile` from the `entrypoint.sh` file)
        1. Create an admin user on MongoDB `local` db (db used for replicaSets)
        
            ```bash  
            user@computer:kobo-install$ ./run.py -cb exec mongo bash
            root@mongo:/$ mongo -u root -p "$MONGO_INITDB_ROOT_PASSWORD" admin
            > db.createUser(
               {
                  user: "localRoot",
                  pwd: "<randomPassword>",
                  roles: [ { role: "dbAdmin", db: "local" } ]
               }
            )
            > exit
            root@mongo:/$ mongo -u localRoot -p <randomPassword> admin
            > use local;
            > db.dropDatabase();
            > exit
            root@mongo:/$ mongo -u root -p "$MONGO_INITDB_ROOT_PASSWORD" admin
            > db.dropUser('localRoot');
            ```
           
    **You can now run the command described above to validate your MongoDB isntance is using `WiredTiger`.**      
       
1. Upgrade to 3.6

    1. Stop `mongo` container

        ```shell
        user@computer:kobo-install$ python3 run.py -cb stop mongo  
        ```
       
    1. Edit composer file `docker-compose.primary.backend.template.yml` and change image to `mongo:3.6`

        ```
        mongo:
          image: mongo:3.6
        ```
   
    1. Start the container: 
        
        ```shell
        user@computer:kobo-install$ python3 run.py -cb up --force-recreate mongo  
           ```
           
    1. Wait for MongoDB to be ready. You should see in the console the output below: 

        ```
        mongo_1        | {
        mongo_1        |     "numIndexesBefore" : 3,
        mongo_1        |     "numIndexesAfter" : 3,
        mongo_1        |     "note" : "all indexes already exist",
        mongo_1        |     "ok" : 1
        mongo_1        | }
        ```

    1. From another terminal, enter the container and update compatibility version.

        ```shell
        root@mongo:/# mongo -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" admin
        > db.adminCommand( { setFeatureCompatibilityVersion: "3.6" } )
        { "ok" : 1 }
        > exit
        bye
        root@mongo:/# exit
        ```
        
1. Upgrade to 4.0, 4.2, 4.4 and 5.0

    Repeat the steps above for each version and replace the version accordingly.
    You **must** upgrade each version one by one.
    
    Then start the container:
     
    ```shell
     user@computer:kobo-install$ python3 run.py -cb up -d --force-recreate mongo     
    ```

    Done!


### Tests

1. Test if upgrade is successful

    Start your containers as usual.

    ```shell
    user@computer:kobo-install$ python3 run.py  
    ```

    Log into one of your user accounts and validate everything is working as expected.         

### Cleaning up

   If everything is ok, you can now delete data from `PostgreSQL 9.5`

   1. Stop containers
    
        ```shell
        user@computer:kobo-install$ python3 run.py --stop  
        ```
    
   1. Rename folder
    
        ```shell
        user@computer:kobo-docker$ sudo rm -rf .vols/db
        user@computer:kobo-docker$ sudo mv .vols/db14 .vols/db
        ```
   1. Update `docker-compose.backend.template.yml` to map correct volume

        ```
        postgres:
            image: postgis/postgis:14-3.2
            ...
            volumes:
              - ./.vols/db:/var/lib/postgresql/data
              ...
        ```

   

   Done!
