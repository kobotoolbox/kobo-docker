# Setup procedure:
1. Clone this repository, retaining the directory name `kobo-docker`.
2. [Install Docker Compose on 64-bit Linux](https://docs.docker.com/compose/install/). Power users on Mac OS X and Windows can try [the new Docker beta for those platforms](https://blog.docker.com/2016/03/docker-for-mac-windows-beta/), but there are known issues with filesystem syncing on those platforms.
3. Determine whether you want to create an HTTP-only **local** instance of KoBo Toolbox, or a HTTPS publicly-accessible **server** instance. Local instances will use [`docker-compose.local.yml`](./docker-compose.local.yml) and [`envfile.local.txt`](./envfile.local.txt), whereas server instances will use [`docker-compose.server.yml`](./docker-compose.server.yml) and [`envfile.server.txt`](./envfile.server.txt) instead.  
**Note:** For server instances, you are expected to meet the usual basic requirements of serving over HTTPS. That is, DNS records for your domain and subdomains specified in [`envfile.server.txt`](./envfile.server.txt), as well as a CA-signed wildcard (or SAN) SSL certificate+key pair valid for those subdomains, and some basic knowledge of Nginx server administration and the use of SSL.
4. Based on your desired instance type, create a symlink named `docker-compose.yml` to either [`docker-compose.local.yml`](./docker-compose.local.yml) or [`docker-compose.server.yml`](./docker-compose.server.yml) (e.g. `ln -s docker-compose.local.yml docker-compose.yml`). Alternatively, you can skip this step and explicitly prefix all Docker Compose commands as follows: `docker-compose -f docker-compose.local.yml ...`.
5. Pull the latest images from Docker Hub: `docker-compose pull`. **Note:** Pulling updated images doesn't remove the old ones, so if your drive is filling up, try removing outdated images with e.g. `docker rmi`.
6. Edit the appropriate environment file for your instance type, [`envfile.local.txt`](./envfile.local.txt) or [`envfile.server.txt`](./envfile.server.txt), filling in **all** mandatory variables, and optional variables as needed.
8. Optionally enable additional settings for your Google Analytics token, S3 bucket, e-mail settings, etc. by editing the files in [`envfiles/`](./envfiles).
9. **Server-only steps:**
  1. Make a `secrets` directory in the project root and copy the SSL certificate and key files to `secrets/ssl.crt` and `secrets/ssl.key` respectively. **The certificate and key are expected to use exactly these filenames and must comprise either a wildcard or SAN certificate+key pair which are valid for the domain and subdomains specified in [`envfile.server.txt`](./envfile.server.txt).**
  2. If testing on a server that is not publicly accessible at the subdomains you've specified in [`envfile.server.txt`](./envfile.server.txt), put an entry in your host machine's `/etc/hosts` file for each of the three subdomains you entered to reroute such requests to your machine's address (e.g. `192.168.1.123 kf-local.kobotoolbox.org`). Also, uncomment and customize the `extra_hosts` directives in [`docker-compose.server.yml`](./docker-compose.server.yml).
<!-- 8. Optionally stop and clear previously built `kobo-docker` containers: `docker-compose stop; docker-compose rm`. -->
<!-- 9. Optionally clear persisted files (e.g. the Postgres database) from previous runs, **taking care that you are in the `kobo-docker` directory**: `sudo rm -rf .vols/ log/`. -->
10. Build any images you've chosen to manually override: `docker-compose build`.
11. Start the server: `docker-compose up -d` (or without the `-d` option to run in the foreground).
11. Container output can be followed with `docker-compose logs -f`. For an individual container, logs can be followed by using the container name from your `docker-compose.yml` with e.g. `docker-compose logs -f enketo_express`.

"Local" setup users can now reach KoBo Toolbox at `http://${HOST_ADDRESS}:${KPI_PUBLIC_PORT}` (substituting in the values entered in [`envfile.local.txt`](./envfile.local.txt)), while "server" setups can be reached at `https://${KOBOFORM_PUBLIC_SUBDOMAIN}.${PUBLIC_DOMAIN_NAME}` (similarly substituting from [`envfile.server.txt`](./envfile.server.txt)). Be sure to periodically update your containers, especially `nginx`, for security updates by pulling new changes from this `kobo-docker` repo then running e.g. `docker-compose pull && docker-compose up -d`.

# Backups
Automatic, periodic backups of KoBoCAT media, MongoDB, and Postgres can be individually enabled by uncommenting (and optionally customizing) the `*_BACKUP_SCHEDULE` variables in your `envfile`. When enabled, timestamped backups will be placed in `backups/kobocat`, `backups/mongo`, and `backups/postgres`, respectively. Redis backups are currently not generated, but the `redis_main` DB file is updated every 5 minutes and can always be found in `.vols/redis_main_data/`.

Backups can also be manually triggered when `kobo-docker` is running by executing the the following commands:
```
docker exec -it kobodocker_kobocat_1 /srv/src/kobocat/docker/backup_media.bash
docker exec -it kobodocker_mongo_1 /srv/backup_mongo.bash
docker exec -it kobodocker_postgres_1 /srv/backup_postgres.bash
```
