## Upgrading from Redis 7.2 to Valkey 9.1

In September 2026, kobo-docker replaced Redis 7.2 with [Valkey](https://valkey.io) 9.
Valkey is a drop-in replacement for Redis: it speaks the same protocol and loads the data files Redis already wrote, so **your existing data is kept** and no dump/restore is needed. Downtime is usually under a minute.

While the change is within kobo-docker, the commands shown below are for [kobo-install](https://github.com/kobotoolbox/kobo-install) and expected to be run in the directory containing kobo-install, unless stated otherwise.

### What changed

- `redis_main` and `redis_cache` now run the `valkey/valkey:9.1` image instead of `redis:7.2`.
- Service names, internal hostnames (`redis-main.*`, `redis-cache.*`), ports, `REDIS_*` environment variables and connection URLs are **unchanged**. KPI and Enketo need no configuration changes, and neither does a separate front-end server.
- Data stays where it was, in `.vols/redis_main_data/` and `.vols/redis_cache_data/`. Valkey mounts the same folders and loads the same `enketo-main.rdb` / `enketo-cache.rdb` files.
- Backup files are now named `valkey-<version>-<domain>-<date>.gz` instead of `redis-<version>-<domain>-<date>.gz`. S3 backups still go to the `redis/` folders, so retention keeps working.

### Before you start

**Back up your Redis data first.** Once Valkey 9 has saved to disk, it writes a newer file format that Redis 7.2 cannot read, so the backup below is your only way back.

### Upgrading to Valkey

1. Note the current number of keys so you can compare after the upgrade. The password is read from your envfiles inside the container:

    ```shell
    user@computer:kobo-install$ python3 run.py -cb exec redis_main bash -c 'redis-cli -p 6379 -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE'
    user@computer:kobo-install$ python3 run.py -cb exec redis_cache bash -c 'redis-cli -p 6380 -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE'
    ```

1. Stop the Redis containers. Stopping them cleanly makes Redis write everything in memory to disk before exiting.

    ```shell
    user@computer:kobo-install$ python3 run.py -cb stop redis_main redis_cache
    ```

1. Back up the data folders. From your **kobo-docker** directory:

    ```shell
    user@computer:kobo-docker$ sudo cp -a .vols/redis_main_data  .vols/redis_main_data.bak-redis72
    user@computer:kobo-docker$ sudo cp -a .vols/redis_cache_data .vols/redis_cache_data.bak-redis72
    ```

    Check that `.vols/redis_main_data.bak-redis72/enketo-main.rdb` exists and is not empty.

1. Update kobo-docker to the version that uses Valkey (kobo-install does this for you when you upgrade it), or pull it manually from your kobo-docker directory:

    ```shell
    user@computer:kobo-docker$ git pull
    ```

    `docker-compose.backend.yml` should now contain `image: valkey/valkey:9.1` for both `redis_main` and `redis_cache`.

1. Pull the new image and recreate the two containers:

    ```shell
    user@computer:kobo-install$ python3 run.py -cb pull redis_main redis_cache
    user@computer:kobo-install$ python3 run.py -cb up --force-recreate -d redis_main redis_cache
    ```

### Tests

1. Check that Valkey loaded your existing data. The logs are written to files in your kobo-docker directory:

    ```shell
    user@computer:kobo-docker$ tail -n 30 log/redis_main/redis-enketo-main.log
    user@computer:kobo-docker$ tail -n 30 log/redis_cache/redis-enketo-cache.log
    ```

    You should see a `Loading RDB produced by ... 7.2.x` line followed by `DB loaded from disk`.

1. Compare the key counts with the numbers you noted in step 1:

    ```shell
    user@computer:kobo-install$ python3 run.py -cb exec redis_main bash -c 'valkey-cli -p 6379 -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE'
    user@computer:kobo-install$ python3 run.py -cb exec redis_cache bash -c 'valkey-cli -p 6380 -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE'
    ```

    The counts may differ slightly because keys with an expiry time may have expired in the meantime.

1. Start your containers as usual, log into one of your user accounts and open an Enketo form to confirm everything works.

    ```shell
    user@computer:kobo-install$ python3 run.py
    ```

1. Once you are satisfied, you can delete the `.bak-redis72` folders.

### Troubleshooting

- **The container exits right after starting.** Look at `log/redis_main/redis-enketo-main.log` (or the cache log). Valkey reports any configuration directive it rejects by name.
- **Rolling back to Redis 7.2.** Stop the containers, restore the backup and switch the image back:

    ```shell
    user@computer:kobo-install$ python3 run.py -cb stop redis_main redis_cache
    user@computer:kobo-docker$ sudo rm -rf .vols/redis_main_data .vols/redis_cache_data
    user@computer:kobo-docker$ sudo mv .vols/redis_main_data.bak-redis72  .vols/redis_main_data
    user@computer:kobo-docker$ sudo mv .vols/redis_cache_data.bak-redis72 .vols/redis_cache_data
    ```

    Then check out the previous kobo-docker version (or set both images back to `redis:7.2` in `docker-compose.backend.yml`) and run `python3 run.py -cb up --force-recreate -d redis_main redis_cache`. Anything written to Valkey after the upgrade is lost.
