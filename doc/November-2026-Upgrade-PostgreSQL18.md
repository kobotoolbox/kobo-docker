## Upgrading from PostgreSQL 14 to PostgreSQL 18

PostgreSQL 14 reached its [end of life on November 12, 2026](https://www.postgresql.org/support/versioning/): it no longer receives security or bug fixes.
In November 2026, kobo-docker was updated to use **PostgreSQL 18 with PostGIS 3.6** (`postgis/postgis:18-3.6`).

If your installation still runs PostgreSQL 14, you must follow these one-time instructions **before** starting the new version.
A PostgreSQL 18 server cannot read a PostgreSQL 14 data directory: the data has to be converted with `pg_upgrade`.

This procedure:

- uses `pg_upgrade` in **copy mode**, so your PostgreSQL 14 data directory is **never modified**. Rolling back is a matter of renaming a folder.
- jumps directly from 14 to 18. Unlike MongoDB, PostgreSQL does **not** require upgrading one major version at a time.
- incurs downtime. Count roughly 1 minute per GB of data, plus a few minutes of setup.

While the PostgreSQL version change is within kobo-docker, the commands shown below are for [kobo-install](https://github.com/kobotoolbox/kobo-install) and are expected to be run in the directory containing kobo-install (or kobo-docker, when stated).
If you do not use kobo-install, replace `python3 run.py -cb` with `docker compose -f docker-compose.backend.yml -f docker-compose.backend.override.yml [-f docker-compose.backend.custom.yml]`.

### What changes in PostgreSQL 18 images (read this first)

1. **New default `PGDATA`.** Official PostgreSQL 18+ images store data in `/var/lib/postgresql/18/docker` (it used to be `/var/lib/postgresql/data`).
    kobo-docker now sets `PGDATA=/var/lib/postgresql/data` in `docker-compose.backend.yml` to keep the historical location.
    **If you override the `postgres` service** (e.g. in `docker-compose.backend.custom.yml`), make sure you do not remove this variable.
    Otherwise PostgreSQL silently initializes a **new, empty** cluster and KoboToolbox looks like all your data has disappeared.

1. **Data checksums are enabled by default** by `initdb` in PostgreSQL 18.
    Clusters created by kobo-docker with older versions do not use them, and `pg_upgrade` refuses to upgrade between clusters whose checksum settings differ.
    The new cluster must therefore be initialized with `--no-data-checksums` (done below).

1. **PostGIS tiger geocoder.** Starting with PostGIS 3.7, `postgis_tiger_geocoder` is shipped in a separate package (`postgresql-18-postgis-tiger-geocoder`), uses date-based versions (e.g. `2025.2`), and is not included in the `postgis/postgis:18-3.7` image.
    This is why kobo-docker uses `postgis/postgis:18-3.6`. See [Troubleshooting](#troubleshooting) if you use PostGIS 3.7.

### Before you start

1. **Back up your database.** Even though this procedure does not touch your PostgreSQL 14 data, take a dump first:

    ```shell
    user@computer:kobo-install$ python3 run.py -cb exec postgres bash -c 'PGUSER="$POSTGRES_USER" bash /kobo-docker-scripts/scripts/backup-to-disk.bash'
    ```

    _Notes: Older versions of `backup-to-disk.bash` do not set `PGUSER` themselves when run by hand. Without it, `pg_dump` connects as `root` and fails with `FATAL: role "root" does not exist`._

    The dumps are written to `kobo-docker/backups/postgres`, one file per database (KPI and KoboCAT). **Check that they are not empty**:

    ```shell
    user@computer:kobo-docker$ ls -lh backups/postgres
    ```

    Older versions of the script leave **0-byte files** behind when `pg_dump` fails. A 0-byte file is not a backup.
    Copy the dumps somewhere safe (outside `kobo-docker`): **the script deletes previous dumps each time it runs.**

    If you need to restore them later:

    ```shell
    root@postgres:/# pg_restore -U "$POSTGRES_USER" --clean --if-exists -d "$KPI_POSTGRES_DB" /srv/backups/postgres-<kpi-db>-14-<domain>-<date>.pg_dump
    root@postgres:/# pg_restore -U "$POSTGRES_USER" --clean --if-exists -d "$KC_POSTGRES_DB" /srv/backups/postgres-<kobocat-db>-14-<domain>-<date>.pg_dump
    ```

    A `pg_dump` taken from PostgreSQL 14 can be restored into PostgreSQL 18.

1. **Check free disk space.** Copy mode duplicates your data. You need _more_ free space than the size of `.vols/db`:

    ```shell
    user@computer:kobo-docker$ sudo du -hs .vols/db
    user@computer:kobo-docker$ df -h .
    ```

1. **Write down the cluster settings**. The new cluster must be initialized with the same superuser and locale:

    ```shell
    user@computer:kobo-install$ python3 run.py -cb exec postgres bash -c 'echo "user: $POSTGRES_USER"; psql -U "$POSTGRES_USER" -d postgres -Atc "SHOW lc_collate" -c "SHOW server_encoding" -c "SHOW data_checksums"'
    ```

    Typical output:

    > ```
    > user: kobo
    > en_US.utf8
    > UTF8
    > off
    > ```

    If `data_checksums` is `on`, remove `--no-data-checksums` from the `initdb` command below.

### Upgrading PostgreSQL

1. Stop the containers

    ```shell
    user@computer:kobo-install$ python3 run.py --stop
    ```

    Make sure PostgreSQL was shut down cleanly: `kobo-docker/.vols/db/postmaster.pid` must **not** exist.

1. Run a one-off PostgreSQL 18 container

    The old data directory is mounted as `/var/lib/postgresql/14/data` and a new, empty folder `.vols/db18` as `/var/lib/postgresql/18/data`.

    ```shell
    user@computer:kobo-docker$ docker run --rm -it \
        --env-file ../kobo-env/envfiles/databases.txt \
        -v "$PWD/.vols/db:/var/lib/postgresql/14/data" \
        -v "$PWD/.vols/db18:/var/lib/postgresql/18/data" \
        postgis/postgis:18-3.6 bash
    ```

1. Install PostgreSQL 14 binaries (and PostGIS for both versions)

    `pg_upgrade` needs the binaries of **both** versions. The image only knows the PostgreSQL 18 repository, so we add PostgreSQL 14 to it:

    ```shell
    root@container:/# sed -i 's/ main 18$/ main 18 14/' /etc/apt/sources.list.d/pgdg.list && \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            postgresql-14 postgresql-14-postgis-3 postgresql-18-postgis-3
    ```

    _Notes: On `postgis/postgis:18-3.6`, `postgresql-18-postgis-3` is already installed and apt may upgrade it. That is fine: only the `postgis-3` library has to exist in the new cluster._

1. Initialize the PostgreSQL 18 cluster

    ```shell
    root@container:/# chown -R postgres:postgres /var/lib/postgresql/14/data /var/lib/postgresql/18/data && \
        chmod 700 /var/lib/postgresql/18/data && \
        su postgres -c "/usr/lib/postgresql/18/bin/initdb -U $POSTGRES_USER \
            --encoding=UTF8 --locale=en_US.utf8 --no-data-checksums \
            -D /var/lib/postgresql/18/data"
    ```

    **It is important to initialize the PostgreSQL 18 cluster with the same username, encoding and locale as the PostgreSQL 14 cluster** (see [Before you start](#before-you-start)).
    Ensure that `$POSTGRES_USER` equals that username. If it is not the case, replace `$POSTGRES_USER` with the correct username (in all following instructions).

    Results should look like this:

    > ```
    > Success. You can now start the database server using:
    > ```

1. Check that the clusters are compatible

    ```shell
    root@container:/# cd /tmp && su postgres -c "/usr/lib/postgresql/18/bin/pg_upgrade --check \
        --old-datadir=/var/lib/postgresql/14/data \
        --new-datadir=/var/lib/postgresql/18/data \
        --old-bindir=/usr/lib/postgresql/14/bin \
        --new-bindir=/usr/lib/postgresql/18/bin \
        -U $POSTGRES_USER"
    ```

    Results should end with:

    > ```
    > *Clusters are compatible*
    > ```

    If you get `old cluster does not use data checksums but the new one does`, delete `.vols/db18`, then initialize the cluster again with `--no-data-checksums`.

1. Upgrade

    Run the same command **without** `--check`:

    ```shell
    root@container:/# cd /tmp && su postgres -c "/usr/lib/postgresql/18/bin/pg_upgrade \
        --old-datadir=/var/lib/postgresql/14/data \
        --new-datadir=/var/lib/postgresql/18/data \
        --old-bindir=/usr/lib/postgresql/14/bin \
        --new-bindir=/usr/lib/postgresql/18/bin \
        -U $POSTGRES_USER"
    ```

    Results should look like this:

    > ```
    > Checking for extension updates                                notice
    >
    > Your installation contains extensions that should be updated
    > with the ALTER EXTENSION command.
    > ...
    > Upgrade Complete
    > ----------------
    > ```

    The notice about extensions is expected: PostGIS is updated in a later step.
    Ignore the `delete_old_cluster.sh` suggestion; cleanup is covered [below](#cleaning-up).

1. Carry over kobo-docker files and exit

    kobo-docker marks its data directory with a `kobo_first_run` file. Without it, the init scripts would run again on an existing database.

    ```shell
    root@container:/# cp -p /var/lib/postgresql/14/data/kobo_first_run /var/lib/postgresql/18/data/ && \
        cp -p /var/lib/postgresql/14/data/pg_hba.conf /var/lib/postgresql/18/data/ && \
        exit
    ```

    _Notes: `postgresql.conf` and `pg_hba.conf` are regenerated by kobo-docker at each start, from `kobo-docker/postgres/conf/` (or your override in `kobo-env/postgres/conf/`)._

1. Swap the data directories

    The PostgreSQL 14 data is kept as `.vols/db.pg14`, so the volume path in the compose files does not change.

    ```shell
    user@computer:kobo-docker$ sudo mv .vols/db .vols/db.pg14 && \
        sudo mv .vols/db18 .vols/db && \
        cat .vols/db/PG_VERSION
    ```

    It should print `18`.

1. Update kobo-docker

    If you have not done it yet, pull the version of kobo-docker that uses PostgreSQL 18 (kobo-install does it for you with `python3 run.py --update`).
    `docker-compose.backend.yml` should contain:

    ```yml
      postgres:
        image: postgis/postgis:18-3.6
        hostname: postgres
        environment:
          - PGDATA=/var/lib/postgresql/data
    ```

    If you override the image in `docker-compose.backend.custom.yml` (e.g. `postgres:14`), change it to the PostgreSQL 18 equivalent.
    If you use a custom entrypoint, replace any hard-coded `/usr/lib/postgresql/14/` path with `/usr/lib/postgresql/${PG_MAJOR}/`.

1. Start PostgreSQL only

    ```shell
    user@computer:kobo-install$ python3 run.py -cb up -d postgres
    user@computer:kobo-install$ python3 run.py -cb logs -f postgres
    ```

    Wait for:

    > ```
    > LOG:  starting PostgreSQL 18.x ...
    > ...
    > LOG:  database system is ready to accept connections
    > ```

    If the log shows `initializing database` or `Skipping initialization` is missing on a known database, **stop immediately**: `PGDATA` is not set correctly (see [What changes](#what-changes-in-postgresql-18-images-read-this-first)).

1. Update PostGIS extensions

    ```shell
    user@computer:kobo-install$ python3 run.py -cb exec postgres bash
    root@postgres:/# for DB in "$KC_POSTGRES_DB" "$KPI_POSTGRES_DB"; do
        echo "== $DB"
        psql -U "$POSTGRES_USER" -d "$DB" -q -c "SELECT postgis_extensions_upgrade();"
        psql -U "$POSTGRES_USER" -d "$DB" -q -c "ALTER EXTENSION fuzzystrmatch UPDATE;"
        psql -U "$POSTGRES_USER" -d "$DB" -Atc "SELECT extname || ' ' || extversion FROM pg_extension ORDER BY 1;"
    done
    ```

    You may see `INFO` messages about topology columns being upgraded to `bigint`, and `WARNING: attribute versions of relation "validatetopology_returntype" are non-monotonic`. Both are harmless.

    `postgis`, `postgis_topology` and `postgis_tiger_geocoder` should all report the new PostGIS version (e.g. `3.6.4`).
    Depending on your kobo-docker environment, databases may have other names. Run the loop on every database that has PostGIS.

1. Rebuild optimizer statistics

    `pg_upgrade` does not carry over all planner statistics. Until they are rebuilt, some queries may be slow.

    ```shell
    root@postgres:/# vacuumdb -U "$POSTGRES_USER" --all --analyze-in-stages --missing-stats-only && \
        vacuumdb -U "$POSTGRES_USER" --all --analyze-only
    root@postgres:/# exit
    ```

    The application can be started while the second command runs.

### Tests

1. Test if upgrade is successful

    Start your containers as usual.

    ```shell
    user@computer:kobo-install$ python3 run.py
    ```

    Open `https://<your-kpi-domain>/service_health/`. Both `Postgres kpi` and `Postgres kobocat` should be `OK`.

    Log into one of your user accounts and validate everything is working as expected (projects list, form deployment, submissions, data table, exports).

### Rolling back

As long as `.vols/db.pg14` exists, you can go back to PostgreSQL 14:

```shell
user@computer:kobo-install$ python3 run.py --stop
user@computer:kobo-docker$ sudo mv .vols/db .vols/db18 && sudo mv .vols/db.pg14 .vols/db
```

Then restore the previous image (`postgis/postgis:14-3.2`) in your compose file and start again.
**Any data written while running PostgreSQL 18 is lost when rolling back.**

### Cleaning up

If everything is ok, you can delete the PostgreSQL 14 data:

```shell
user@computer:kobo-docker$ sudo rm -rf .vols/db.pg14
```

Done!

### Troubleshooting

- **`old cluster does not use data checksums but the new one does`**: see step "Check that the clusters are compatible".

- **`could not load library "$libdir/postgis-3"`** during `pg_upgrade --check`: `postgresql-18-postgis-3` is not installed in the one-off container.

- **`FATAL: database "template_postgis" does not exist`** in the logs at startup: the image's `update-postgis.sh` expects a `template_postgis` database that older kobo-docker installations do not have. It does not prevent PostgreSQL from starting, and was already the case with PostgreSQL 14.

- **`postgis_tiger_geocoder` stays at its old version** (e.g. `3.3.1`), or `ALTER EXTENSION` fails with `has no update path from version "3.3.1" to version "2025.2"` (PostGIS 3.7+).
    KoboToolbox does not use the tiger geocoder (a US census geocoder). Its `tiger` schemas only contain lookup tables shipped with the extension, so it can safely be re-created.
    First make sure nothing depends on it. The `DROP` below has no `CASCADE`, so it fails instead of removing dependent objects:

    ```shell
    root@postgres:/# for DB in "$KC_POSTGRES_DB" "$KPI_POSTGRES_DB"; do
        psql -U "$POSTGRES_USER" -d "$DB" -v ON_ERROR_STOP=1 -c "BEGIN; DROP EXTENSION postgis_tiger_geocoder; CREATE EXTENSION postgis_tiger_geocoder; COMMIT;"
    done
    ```

    With PostGIS 3.7+, the package `postgresql-18-postgis-tiger-geocoder` must be installed first.
