# Temporary setup procedure:
1. [Install Docker Compose on Linux or OS X](https://docs.docker.com/compose/install/). Windows power users who've installed Python and `pip` can try [this hint from the Docker Compose repository](https://github.com/docker/compose/issues/1085#issuecomment-142491609).
2. Determine whether you want to create an HTTP-only local instance of KoBo Toolbox, or a HTTPS publicly-accessible server instance (for testing, there are workarounds if your server is not yet publicly accessible).
2. Create a symlink from either [`docker-compose.local.yml`](./docker-compose.local.yml) or [`docker-compose.server.yml`](./docker-compose.server.yml) to `docker-compose.yml` (e.g. `ln -s docker-compose.local.yml docker-compose.yml`). Otherwise, you'll have to prefix all Docker Compose commands like `docker-compose -f docker-compose.local.yml`.
3. Pull the latest images from Docker Hub: `docker-compose pull`.
4. Build any overridden images: `docker-compose build`.
3. Edit the appropriate environment file, [`envfile.local.txt`](./envfile.local.txt) or [`envfile.server.txt`](./envfile.server.txt), filling in **all** mandatory variables, and optional variables as needed.
4. Server-specific:
  1. Make a `secrets` directory in the project root and copy the SSL certificate and key files to `secrets/ssl.crt` and `secrets/ssl.key` respectively. **The certificate and key are expected to use exactly these names and must comprise a wildcard or SAN certificate valid for the domain and subdomains named in [`envfile.server.txt`](./envfile.server.txt).**
  2. If testing on a server that is not publicly accessible at the subdomains you've specified in [`envfile.server.txt`](./envfile.server.txt), put an entry in your host machine's `/etc/hosts` file for each of the three subdomains you entered to reroute such requests to your machine's address (e.g. `192.168.1.1 kf-local.kobotoolbox.org`). Also, uncomment and configure the `extra_hosts` directives in [`docker-compose.server.yml`](./docker-compose.server.yml).
5. Optionally clear persisted files from previous runs: `sudo rm -rf .vols/ log/`
6. Optionally stop and clear previously built `kobo-docker` containers: `docker-compose stop; docker-compose rm`
7. As a temporary workaround to avoid a race condition, manually initiate `kpi` database sync and migrations (quit with `CTRL+C` once UWSGI has started): `docker-compose run --rm kpi`
8. As a temporary workaround to avoid a race condition, manually initiate `dkobo` (yes, really) database sync and migrations, and initialize an admin user with credentials `kobo:kobo` (quit with `CTRL+C` once UWSGI has started): `docker-compose run --rm dkobo`
9. As a temporary workaround to avoid a race condition, manually initiate `kobocat` database sync and migrations (quit with `CTRL+C` once UWSGI has started): `docker-compose run --rm kobocat`
10. Start the server: `docker-compose up` (or with `up -d` to run in background)
11. Logs for an individual container can be viewed by using the container name from your `docker-compose.yml` with e.g. `docker-compose logs enketo_express`.

# TODO
* KoBoCAT login redirect (e.g https://kf-local.kobotoolbox.org/accounts/login/?next=/kobocat/ -> https://kf-local.kobotoolbox.org/kobocat/ -> `404`)
* SMTP e-mail?
* Maps?
