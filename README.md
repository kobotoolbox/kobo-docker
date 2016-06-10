# Temporary setup procedure:
1. [Install Docker Compose on 64-bit Linux](https://docs.docker.com/compose/install/). OS X and Windows power users can try [the new Docker beta for those platforms](https://blog.docker.com/2016/03/docker-for-mac-windows-beta/).
2. Determine whether you want to create an HTTP-only **local** instance of KoBo Toolbox, or a HTTPS publicly-accessible **server** instance. Local instances will use [`docker-compose.local.yml`](./docker-compose.local.yml) and [`envfile.local.txt`](./envfile.local.txt), whereas server instances will use [`docker-compose.server.yml`](./docker-compose.server.yml) and [`envfile.server.txt`](./envfile.server.txt) instead.  
**Note:** For server instances, you are expected to meet the usual basic requirements of serving over HTTPS. That is, DNS records for your domain and subdomains, a CA-signed wildcard (or SAN) SSL certificate valid for those subdomains, and some basic knowledge of Nginx server administration and the use of SSL.
3. Based on your desired instance type, create a symlink named `docker-compose.yml` to either [`docker-compose.local.yml`](./docker-compose.local.yml) or [`docker-compose.server.yml`](./docker-compose.server.yml) (e.g. `ln -s docker-compose.local.yml docker-compose.yml`). Alternatively, you can skip this step and explicitly prefix all Docker Compose commands like `docker-compose -f docker-compose.local.yml`.
4. Pull the latest images from Docker Hub: `docker-compose pull`. **Note:** Be careful when pulling updated images to delete the old using `docker rmi` so your drive doesn't fill up.
5. Build any images you've chosen to manually override: `docker-compose build`.
6. Edit the appropriate environment file for your instance type, [`envfile.local.txt`](./envfile.local.txt) or [`envfile.server.txt`](./envfile.server.txt), filling in **all** mandatory variables, and optional variables as needed.
7. **Server-only steps:**
  1. Make a `secrets` directory in the project root and copy the SSL certificate and key files to `secrets/ssl.crt` and `secrets/ssl.key` respectively. **The certificate and key are expected to use exactly these filenames and must comprise either a wildcard or SAN certificate+key pair which are valid for the domain and subdomains specified in [`envfile.server.txt`](./envfile.server.txt).**
  2. If testing on a server that is not publicly accessible at the subdomains you've specified in [`envfile.server.txt`](./envfile.server.txt), put an entry in your host machine's `/etc/hosts` file for each of the three subdomains you entered to reroute such requests to your machine's address (e.g. `192.168.1.1 kf-local.kobotoolbox.org`). Also, uncomment and configure the `extra_hosts` directives in [`docker-compose.server.yml`](./docker-compose.server.yml).
8. Optionally stop and clear previously built `kobo-docker` containers: `docker-compose stop; docker-compose rm`.
9. Optionally clear persisted files (e.g. the Postgres database) from previous runs, **taking care that you are in the `kobo-docker` directory**: `sudo rm -rf .vols/ log/`.
10. Start the server: `docker-compose up -d` (or without the `-d` option to run in the foreground).
11. Container output can be viewed with `docker-compose logs`. For an individual container, logs can be viewed by using the container name from your `docker-compose.yml` with e.g. `docker-compose logs enketo_express`.
12. Be sure to periodically update your containers, especially `nginx`, for security updates with e.g. `git pull && docker-compose pull && docker-compose up -d`.

# TODO
* KoBoCAT login redirect (e.g https://kc-local.kobotoolbox.org -> https://kf-local.kobotoolbox.org/accounts/login/?next=/kobocat/ -> https://kf-local.kobotoolbox.org/kobocat/ -> `404`)
* Maps?
